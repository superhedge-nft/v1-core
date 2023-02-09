// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./interfaces/ISHProduct.sol";
import "./interfaces/ISHNFT.sol";
import "./interfaces/clearpool/IPoolMaster.sol";
import "./interfaces/compound/ICErc20.sol";
import "./libraries/DataTypes.sol";
import "./libraries/Array.sol";

contract SHProduct is ReentrancyGuardUpgradeable, PausableUpgradeable {
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

    /// @notice Event emitted when new issuance cycle is updated
    event UpdateParameters(
        uint256 _coupon,
        uint256 _strikePrice1,
        uint256 _strikePrice2,
        uint256 _strikePrice3,
        uint256 _strikePrice4,
        uint256 _tr1,
        uint256 _tr2,
        string _apy,
        string _uri
    );

    event FundAccept(
        uint256 _optionProfit,
        uint256 _prevTokenId,
        uint256 _currentTokenId,
        uint256 _numOfHolders,
        uint256 _timestamp
    );

    event FundLock(
        uint256 _timestamp
    );

    event Issuance(
        uint256 _currentTokenId,
        uint256 _prevHolders,
        uint256 _timestamp
    );

    event Mature(
        uint256 _prevTokenId,
        uint256 _currentTokenId,
        uint256 _timestamp
    );
    
    event WeeklyCoupon(
        uint256 _coupon,
        uint256 _numOfNftHolders,
        uint256 _timestamp
    );

    event UpdateCoupon(
        uint256 _newCoupon
    );

    event UpdateStrikePrices(
        uint256 _strikePrice1,
        uint256 _strikePrice2,
        uint256 _strikePrice3,
        uint256 _strikePrice4
    );

    event UpdateURI(
        uint256 _currentTokenId,
        string _uri
    );

    event UpdateTRs(
        uint256 _newTr1,
        uint256 _newTr2
    );

    event UpdateAPY(
        string _apy
    );

    event UpdateTimes(
        uint256 _issuanceDate,
        uint256 _maturityDate
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
        __ReentrancyGuard_init();
        __Pausable_init();

        name = _name;
        underlying = _underlying;

        manager = _manager;
        qredoWallet = _qredoWallet;
        maxCapacity = _maxCapacity;

        currency = _currency;
        shNFT = _shNFT;

        require(_issuanceCycle.issuanceDate > block.timestamp, 
            "Issuance date should be bigger than current timestamp");
        require(_issuanceCycle.maturityDate > _issuanceCycle.issuanceDate, 
            "Maturity timestamp should be bigger than issuance one");
        
        issuanceCycle = _issuanceCycle;

        ISHNFT(_shNFT).tokenIdIncrement();
        currentTokenId = ISHNFT(shNFT).currentTokenID();
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

    modifier onlyLocked() {
        require(status == Status.Locked, "Not locked status");
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

    modifier LockedOrMature() {
        require(status == Status.Locked || status == Status.Mature, 
            "Neither mature nor locked");
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
        address[] memory totalHolders = ISHNFT(shNFT).accountsByToken(prevTokenId);
        uint256 _optionProfit = optionProfit;
        if (_optionProfit > 0) {
            uint256 totalSupply = ISHNFT(shNFT).totalSupply(prevTokenId);
            for (uint256 i = 0; i < totalHolders.length; i++) {
                uint256 prevSupply = ISHNFT(shNFT).balanceOf(totalHolders[i], prevTokenId);
                userInfo[totalHolders[i]].optionPayout += prevSupply * _optionProfit / totalSupply;
            }
            optionProfit = 0;
        }
        // Then update status
        status = Status.Accepted;

        emit FundAccept(
            _optionProfit, 
            prevTokenId, 
            currentTokenId, 
            totalHolders.length, 
            block.timestamp
        );
    }

    function fundLock() external whenNotPaused onlyAccepted onlyWhitelisted {
        status = Status.Locked;

        emit FundLock(block.timestamp);
    }

    function issuance() external whenNotPaused onlyLocked onlyWhitelisted {
        // burn the token of the last cycle, auto-roll of principal on next cycle
        address[] memory totalHolders = ISHNFT(shNFT).accountsByToken(prevTokenId);

        for (uint256 i = 0; i < totalHolders.length; i++) {
            uint256 prevSupply = ISHNFT(shNFT).balanceOf(totalHolders[i], prevTokenId);
            if (prevSupply > 0) {
                ISHNFT(shNFT).burn(totalHolders[i], prevTokenId, prevSupply);
                ISHNFT(shNFT).mint(totalHolders[i], currentTokenId, prevSupply, issuanceCycle.uri);
            }
        }

        status = Status.Issued;

        emit Issuance(currentTokenId, totalHolders.length, block.timestamp);
    }

    function mature() external whenNotPaused onlyIssued onlyWhitelisted {
        // Update currentTokenId & prevTokenId
        prevTokenId = currentTokenId;

        ISHNFT(shNFT).tokenIdIncrement();
        currentTokenId = ISHNFT(shNFT).currentTokenID();

        status = Status.Mature;

        emit Mature(prevTokenId, currentTokenId, block.timestamp);
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

        emit WeeklyCoupon(issuanceCycle.coupon, totalHolders.length, block.timestamp);
    }

    /**
     * @dev Updates only coupon parameter
     * @param _newCoupon weekly coupon rate in basis point; e.g. 0.10%/wk => 10
     */
    function updateCoupon(
        uint256 _newCoupon
    ) public LockedOrMature onlyManager {
        require(issuanceCycle.coupon != _newCoupon, "Same coupon rate");
        issuanceCycle.coupon = _newCoupon;

        emit UpdateCoupon(_newCoupon);
    }

    /**
     * @dev Updates strike prices
     */
    function updateStrikePrices(
        uint256 _strikePrice1,
        uint256 _strikePrice2,
        uint256 _strikePrice3,
        uint256 _strikePrice4
    ) public LockedOrMature onlyManager {
        issuanceCycle.strikePrice1 = _strikePrice1;
        issuanceCycle.strikePrice2 = _strikePrice2;
        issuanceCycle.strikePrice3 = _strikePrice3;
        issuanceCycle.strikePrice4 = _strikePrice4;

        emit UpdateStrikePrices(
            _strikePrice1, 
            _strikePrice2, 
            _strikePrice3, 
            _strikePrice4
        );
    }

    /**
     * @dev Updates token URI
     */
    function updateURI(
        string memory _newUri
    ) public LockedOrMature onlyManager {
        ISHNFT(shNFT).setTokenURI(currentTokenId, _newUri);
        issuanceCycle.uri = _newUri;

        emit UpdateURI(currentTokenId, _newUri);
    }

    /**
     * @dev Updates TR1 & TR2 (total returns %)
     */
    function updateTRs(
        uint256 _newTr1,
        uint256 _newTr2
    ) public LockedOrMature onlyManager {
        issuanceCycle.tr1 = _newTr1;
        issuanceCycle.tr2 = _newTr2;

        emit UpdateTRs(_newTr1, _newTr2);
    }

    /**
     *
     */
    function updateAPY(
        string memory _apy
    ) public LockedOrMature onlyManager {
        issuanceCycle.apy = _apy;

        emit UpdateAPY(_apy);
    }

    /**
     * @dev Update all parameters for next issuance cycle, called by only manager
     */
    function updateParameters(
        uint256 _coupon,
        uint256 _strikePrice1,
        uint256 _strikePrice2,
        uint256 _strikePrice3,
        uint256 _strikePrice4,
        uint256 _tr1,
        uint256 _tr2,
        string memory _apy,
        string memory _uri
    ) external LockedOrMature onlyManager {

        updateCoupon(_coupon);

        updateStrikePrices(_strikePrice1, _strikePrice2, _strikePrice3, _strikePrice4);

        updateTRs(_tr1, _tr2);

        updateAPY(_apy);

        updateURI(_uri);

        emit UpdateParameters(
            _coupon, 
            _strikePrice1, 
            _strikePrice2,
            _strikePrice3,
            _strikePrice4,
            _tr1,
            _tr2,
            _apy,
            _uri
        );
    }

    /**
     * @dev Update issuance & maturity dates
     */
    function updateTimes(
        uint256 _issuanceDate,
        uint256 _maturityDate
    ) external onlyMature onlyManager {
        require(_issuanceDate > block.timestamp, 
            "Issuance timestamp should be bigger than current one");
        require(_maturityDate > _issuanceDate, 
            "Maturity timestamp should be bigger than issuance one");
        
        issuanceCycle.issuanceDate = _issuanceDate;
        issuanceCycle.maturityDate = _maturityDate;

        emit UpdateTimes(_issuanceDate, _maturityDate);
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
    ) external onlyManager onlyLocked {
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
    ) external onlyManager onlyLocked {
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
