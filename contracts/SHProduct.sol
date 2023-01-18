// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./interfaces/ISHProduct.sol";
import "./interfaces/ISHNFT.sol";
import "./interfaces/clearpool/IPoolMaster.sol";
import "./interfaces/compound/ICErc20.sol";
import "./libraries/DataTypes.sol";
import "./libraries/Array.sol";

contract SHProduct is OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using Array for address[];

    struct UserInfo {
        uint256 coupon;
        uint256 optionPayout;
    }

    /// @notice Enum representing product status
    enum Status {
        Pending,
        Accepted,
        Locked,
        Issued,
        Mature
    }

    string public name;
    string public underlying;

    address public manager;
    address public shNFT;
    address public qredoWallet;

    uint256 public maxCapacity;
    uint256 public currentCapacity;
    uint256 public optionProfit;
    
    uint256 public currentTokenId;
    uint256 public prevTokenId;

    Status public status;
    DataTypes.IssuanceCycle public issuanceCycle;
    
    mapping(address => UserInfo) public userInfo;

    // address[] public investors;

    IERC20Upgradeable public currency;
    bool public isDistributed;

    /// @notice restricting access to the gelato automation functions
    mapping(address => bool) public whitelisted;
    address public dedicatedMsgSender;
    
    event Deposit(
        address indexed _from,
        uint256 _amount,
        uint256 _currentTokenId,
        uint256 _supply
    );

    event WithdrawPrincipal(
        address indexed _to,
        uint256 _amount,
        uint256 _prevTokenId,
        uint256 _prevSupply,
        uint256 _currentTokenId,
        uint256 _currentSupply
    );

    event WithdrawCoupon(
        address indexed _to,
        uint256 _amount
    );

    event WithdrawOption(
        address indexed _to,
        uint256 _amount
    );

    event RedeemOptionPayout(
        address indexed _from,
        uint256 _amount
    );

    event DistributeWithClear(
        address indexed _qredoDeribit,
        uint256 _optionRate,
        address[] _clearpools,
        uint256[] _yieldRates
    );

    event DistributeWithComp(
        address indexed _qredoDeribit,
        uint256 _optionRate,
        address indexed _cErc20Pool,
        uint256 _yieldRate
    );

    event RedeemYieldFromClear(
        address[] _clearpools
    );
    
    event RedeemYieldFromComp(
        address _cErc20Pool
    );

    /// @notice Event emitted when new issuance cycle is set
    event IssuanceCycleSet(
        uint256 coupon,
        uint256 strikePrice1,
        uint256 strikePrice2,
        uint256 strikePrice3,
        uint256 strikePrice4,
        string uri
    );

    event FundAccept(
        uint256 _optionProfit,
        uint256 _prevTokenId,
        uint256 _currentTokenId
    );

    function initialize(
        string memory _name,
        string memory _underlying,
        IERC20Upgradeable _currency,
        address _manager,
        address _shNFT,
        address _qredoWallet,
        uint256 _maxCapacity,
        DataTypes.IssuanceCycle memory _issuanceCycle
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        name = _name;
        underlying = _underlying;

        manager = _manager;
        qredoWallet = _qredoWallet;
        maxCapacity = _maxCapacity;

        currency = _currency;
        shNFT = _shNFT;
        issuanceCycle = _issuanceCycle;

        _setIssuanceCycle(_issuanceCycle);
    }
    
    modifier onlyWhitelisted() {
        require(
            whitelisted[msg.sender] || msg.sender == dedicatedMsgSender,
            "Only whitelisted"
        );
        _;
    }

    /// @notice Modifier for functions restricted to manager
    modifier onlyManager() {
        require(msg.sender == manager, "Not a manager");
        _;
    }

    modifier onlyAccepted() {
        require(status == Status.Accepted, "Not accepted status");
        _;
    }

    modifier onlyIssued() {
        require(status == Status.Issued, "Not issued status");
        _;
    }

    modifier onlyMature() {
        require(status == Status.Mature, "Not mature status");
        _;
    }

    /**
     * @notice Sets dedicated msg.sender to restrict access to the functions that Gelato will call
     */
    function setDedicatedMsgSender(address _sender) external onlyManager {
        dedicatedMsgSender = _sender;
    }

    /**
     * @notice Whitelists the additional callers for the functions that Gelato will call
     */
    function whitelist(address _account) external onlyManager {
        whitelisted[_account] = true;
    }

    function fundAccept() external whenNotPaused onlyWhitelisted {
        // First, distribute option profit to the token holders.
        uint256 totalSupply = ISHNFT(shNFT).totalSupply(currentTokenId);
        address[] memory totalHolders = ISHNFT(shNFT).accountsByToken(currentTokenId);
        if (optionProfit > 0) {
            for (uint256 i = 0; i < totalHolders.length; i++) {
                uint256 tokenSupply = ISHNFT(shNFT).balanceOf(totalHolders[i], currentTokenId);
                userInfo[totalHolders[i]].optionPayout += tokenSupply * optionProfit / totalSupply;
            }
        }
        // Then update status
        status = Status.Accepted;
        prevTokenId = currentTokenId;

        ISHNFT(shNFT).tokenIdIncrement();
        currentTokenId = ISHNFT(shNFT).currentTokenID();

        emit FundAccept(optionProfit, prevTokenId, currentTokenId);
    }

    function fundLock() external whenNotPaused onlyWhitelisted {
        status = Status.Locked;
    }

    function issuance() external whenNotPaused onlyWhitelisted {
        require(status == Status.Locked, "Fund is not locked");
        status = Status.Issued;
        // issuanceCycle.issuanceDate = block.timestamp;
        // burn the token of the last cycle
        address[] memory totalHolders = ISHNFT(shNFT).accountsByToken(currentTokenId);
        for (uint256 i = 0; i < totalHolders.length; i++) {
            uint256 prevSupply = ISHNFT(shNFT).balanceOf(totalHolders[i], prevTokenId);
            if (prevSupply > 0) {
                ISHNFT(shNFT).burn(totalHolders[i], prevTokenId, prevSupply);
                ISHNFT(shNFT).mint(totalHolders[i], currentTokenId, prevSupply, issuanceCycle.uri);
            }
        }
    }

    function mature() external whenNotPaused onlyIssued onlyWhitelisted {
        status = Status.Mature;
        // issuanceCycle.maturityDate = block.timestamp;
    }

    /**
     * @dev Update users' coupon balance every week
     */
    function weeklyCoupon() external whenNotPaused onlyIssued onlyWhitelisted {
        address[] memory totalHolders = ISHNFT(shNFT).accountsByToken(currentTokenId);
        for (uint256 i = 0; i < totalHolders.length; i++) {
            uint256 tokenSupply = ISHNFT(shNFT).balanceOf(totalHolders[i], currentTokenId);
            if (tokenSupply > 0) {
                userInfo[totalHolders[i]].coupon += _convertTokenToCurrency(tokenSupply) * issuanceCycle.coupon / 10000;
            }
        }
    }

    /**
     * @dev Set new issuance cycle, called by only manager
     */
    function setIssuanceCycle(
        DataTypes.IssuanceCycle memory _issuanceCycle
    ) external onlyManager {
        require(status != Status.Issued, "Already issued status");
        _setIssuanceCycle(_issuanceCycle);
    }
    
    function _setIssuanceCycle(
        DataTypes.IssuanceCycle memory _issuanceCycle
    ) internal {
        issuanceCycle = _issuanceCycle;

        emit IssuanceCycleSet(
            _issuanceCycle.coupon, 
            _issuanceCycle.strikePrice1, 
            _issuanceCycle.strikePrice2,
            _issuanceCycle.strikePrice3,
            _issuanceCycle.strikePrice4,
            _issuanceCycle.uri
        );
    }

    /**
     * @dev Deposits the USDC into the structured product and mint ERC1155 NFT
     * @param _amount is the amount of USDC to deposit
     * @param _type True: include profit, False: without profit
     */
    function deposit(uint256 _amount, bool _type) external whenNotPaused nonReentrant onlyAccepted {
        require(_amount > 0, "Amount must be greater than zero");
        
        uint256 amountToDeposit = _amount;
        if (_type == true) {
            amountToDeposit += userInfo[msg.sender].coupon + userInfo[msg.sender].optionPayout;
        }

        uint256 decimals = _currencyDecimals();
        require((amountToDeposit % (1000 * 10 ** decimals)) == 0, "Amount must be whole-number thousands");
        require((maxCapacity * 10 ** decimals) >= (currentCapacity + amountToDeposit), "Product is full");

        uint256 supply = amountToDeposit / (1000 * 10 ** decimals);

        currency.safeTransferFrom(msg.sender, address(this), _amount);
        ISHNFT(shNFT).mint(msg.sender, currentTokenId, supply, issuanceCycle.uri);

        currentCapacity += amountToDeposit;
        if (_type == true) {
            userInfo[msg.sender].coupon = 0;
            userInfo[msg.sender].optionPayout = 0;
        }
        // investors.push(msg.sender);

        emit Deposit(msg.sender, _amount, currentTokenId, supply);
    }

    /**
     * @dev Withdraws the principal from the structured product
     */
    function withdrawPrincipal() external nonReentrant onlyAccepted {
        uint256 prevSupply = ISHNFT(shNFT).balanceOf(msg.sender, prevTokenId);
        uint256 currentSupply = ISHNFT(shNFT).balanceOf(msg.sender, currentTokenId);
        uint256 totalSupply = prevSupply + currentSupply;

        require(totalSupply > 0, "No principal");
        uint256 principal = _convertTokenToCurrency(totalSupply);
        require(totalBalance() >= principal, "Insufficient balance");
        
        currency.safeTransfer(msg.sender, principal);
        ISHNFT(shNFT).burn(msg.sender, prevTokenId, prevSupply);
        ISHNFT(shNFT).burn(msg.sender, currentTokenId, currentSupply);

        currentCapacity -= principal;

        emit WithdrawPrincipal(
            msg.sender, 
            principal, 
            prevTokenId, 
            prevSupply, 
            currentTokenId, 
            currentSupply
        );
    }

    /**
     * @notice Withdraws user's coupon payout
     */
    function withdrawCoupon() external nonReentrant {
        require(userInfo[msg.sender].coupon > 0, "No coupon payout");
        require(totalBalance() >= userInfo[msg.sender].coupon, "Insufficient balance");
        
        currency.safeTransfer(msg.sender, userInfo[msg.sender].coupon);
        userInfo[msg.sender].coupon = 0;

        emit WithdrawCoupon(msg.sender, userInfo[msg.sender].coupon);
    }

    /**
     * @notice Withdraws user's option payout
     */
    function withdrawOption() external nonReentrant {
        require(userInfo[msg.sender].optionPayout > 0, "No option payout");
        require(totalBalance() >= userInfo[msg.sender].optionPayout, "Insufficient balance");
        
        currency.safeTransfer(msg.sender, userInfo[msg.sender].optionPayout);
        userInfo[msg.sender].optionPayout = 0;

        emit WithdrawOption(msg.sender, userInfo[msg.sender].optionPayout);
    }

    function distributeWithComp(
        uint256 _yieldRate,
        address _cErc20Pool
    ) external onlyManager onlyIssued {
        require(!isDistributed, "Already distributed");
        require(_yieldRate <= 100, "Yield rate should be equal or less than 100");
        uint256 optionRate = 100 - _yieldRate;

        uint256 optionAmount;
        if (optionRate > 0) {
            optionAmount = currentCapacity * optionRate / 100;
            currency.transfer(qredoWallet, optionAmount);
        }

        // Lend into the compound cUSDC pool
        uint256 yieldAmount = currentCapacity * _yieldRate / 100;
        currency.approve(_cErc20Pool, yieldAmount);
        ICErc20(_cErc20Pool).mint(yieldAmount);
        isDistributed = true;
        
        emit DistributeWithComp(qredoWallet, optionRate, _cErc20Pool, _yieldRate);
    }

    function redeemYieldFromComp(
        address _cErc20Pool
    ) external onlyManager onlyMature {
        require(isDistributed, "Not distributed");
        uint256 cTokenAmount = ICErc20(_cErc20Pool).balanceOf(address(this));
        // Retrieve your asset based on a cToken amount
        ICErc20(_cErc20Pool).redeem(cTokenAmount);
        isDistributed = false;

        emit RedeemYieldFromComp(_cErc20Pool);
    }

    /**
     * @notice After the fund is locked, distribute USDC into the Qredo wallet and
     * the lending pools to generate passive income
     */
    function distributeWithClear(
        uint256[] calldata _yieldRates, 
        address[] calldata _clearpools
    ) external onlyManager onlyIssued {
        require(!isDistributed, "Already distributed");
        require(_yieldRates.length == _clearpools.length, "Should have the same length");
        uint256 totalYieldRate = 0;
        for (uint256 i = 0; i < _yieldRates.length; i++) {
            totalYieldRate += _yieldRates[i];
        }
        require(totalYieldRate <= 100, "Total yield rate should be equal or less than 100");
        
        uint256 optionRate = 100 - totalYieldRate;
        // Transfer option amount to the Qredo wallet
        if (optionRate > 0) {
            uint256 optionAmount = currentCapacity * optionRate / 100;
            currency.transfer(qredoWallet, optionAmount);
        }

        // Lend into the clearpool
        for (uint256 i = 0; i < _clearpools.length; i++) {
            if (_yieldRates[i] > 0) {
                uint256 yieldAmount = currentCapacity * _yieldRates[i] / 100;
                currency.approve(_clearpools[i], yieldAmount);
                IPoolMaster(_clearpools[i]).provide(yieldAmount);
            }
        }
        isDistributed = true;
        emit DistributeWithClear(qredoWallet, optionRate, _clearpools, _yieldRates);
    }

    function redeemYieldFromClear(
        address[] calldata _clearpools
    ) external onlyManager onlyMature {
        require(isDistributed, "Not distributed");
        require(_clearpools.length > 0, "No yield source");
        for (uint256 i = 0; i < _clearpools.length; i++) {
            uint256 cpTokenBal = IPoolMaster(_clearpools[i]).balanceOf(address(this));
            IPoolMaster(_clearpools[i]).redeem(cpTokenBal);
        }
        isDistributed = false;
        
        emit RedeemYieldFromClear(_clearpools);
    }


    /**
     * @dev Transfers option profit from a qredo wallet, called by an owner
     */
    function redeemOptionPayout(uint256 _optionProfit) external onlyMature {
        require(msg.sender == qredoWallet, "Not a qredo wallet");
        currency.safeTransferFrom(msg.sender, address(this), _optionProfit);
        optionProfit = _optionProfit;

        emit RedeemOptionPayout(msg.sender, _optionProfit);
    }

    /**
     * @notice Returns the user's principal balance
     * Before auto-rolling or fund lock, users can have both tokens so total supply is the sum of 
     * previous supply and current supply
     */
    function principalBalance(address _user) public view returns (uint256) {
        uint256 prevSupply = ISHNFT(shNFT).balanceOf(_user, prevTokenId);
        uint256 tokenSupply = ISHNFT(shNFT).balanceOf(_user, currentTokenId);
        return _convertTokenToCurrency(prevSupply + tokenSupply);
    }

    /**
     * @notice Returns the user's coupon payout
     */
    function couponBalance(address _user) external view returns (uint256) {
        return userInfo[_user].coupon;
    }

    /**
     * @notice Returns the user's option payout
     */
    function optionBalance(address _user) external view returns (uint256) {
        return userInfo[_user].optionPayout;
    }

    /**
     * @notice Returns the product's total USDC balance
     */
    function totalBalance() public view returns (uint256) {
        return currency.balanceOf(address(this));
    }

    /**
     * @notice Returns the decimal of underlying asset (USDC)
     */
    function _currencyDecimals() internal view returns (uint256) {
        return IERC20MetadataUpgradeable(address(currency)).decimals();
    }

    /**
     * @notice Calculates the currency amount based on token supply
     */
    function _convertTokenToCurrency(uint256 _tokenSupply) internal view returns (uint256) {
        return _tokenSupply * 1000 * (10 ** _currencyDecimals());
    }

    /**
     * @dev Pause the product
     */
    function pause() external onlyManager {
        _pause();
    }

    /**
     * @dev Unpause the product
     */
    function unpause() external onlyManager {
        _unpause();
    }
}
