// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./interfaces/ISHProduct.sol";
import "./interfaces/ISHNFT.sol";
import "./interfaces/clearpool/IPoolMaster.sol";
import "./libraries/Array.sol";

contract SHProduct is ISHProduct, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using Array for address[];

    string public name;
    string public underlying;

    address public manager;
    address public shNFT;
    address public qredoDeribit;

    uint256 public maxCapacity;
    uint256 public currentCapacity;
    uint256 public optionProfit;
    
    uint256 public currentTokenId;
    uint256 public prevTokenId;

    Status public status;
    IssuanceCycle public issuanceCycle;
    
    mapping(address => UserInfo) public userInfo;

    address[] public investors;

    IERC20Upgradeable public currency;
    bool public isDistributed;
    address[] public clearpools;
    /// @notice restricting access to the gelato automation functions
    mapping(address => bool) public whitelisted;
    address public dedicatedMsgSender;
    
    function initialize(
        string memory _name,
        string memory _underlying,
        IERC20Upgradeable _currency,
        address _manager,
        address _shNFT,
        address _qredo_deribit,
        uint256 _maxCapacity,
        IssuanceCycle memory _issuanceCycle
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        name = _name;
        underlying = _underlying;

        manager = _manager;
        qredoDeribit = _qredo_deribit;
        maxCapacity = _maxCapacity;

        currency = _currency;
        shNFT = _shNFT;
        issuanceCycle = _issuanceCycle;
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

    modifier onlyQredo() {
        require(msg.sender == qredoDeribit, "Not a deribit wallet");
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

    function fundAccept() external onlyWhitelisted {
        // First, distribute option profit to the token holders.
        uint256 totalSupply = ISHNFT(shNFT).totalSupply(currentTokenId);
        if (optionProfit > 0) {
            for (uint256 i = 0; i < investors.length; i++) {
                uint256 tokenSupply = ISHNFT(shNFT).balanceOf(investors[i], currentTokenId);
                userInfo[msg.sender].optionPayout += tokenSupply * optionProfit / totalSupply;
            }
        }
        // Then update status
        status = Status.Accepted;
        currentCapacity = 0;
        prevTokenId = currentTokenId;

        ISHNFT(shNFT).tokenIdIncrement();
        currentTokenId = ISHNFT(shNFT).currentTokenID();
    }

    function fundLock() external onlyWhitelisted {
        status = Status.Locked;
    }

    function issuance() external onlyWhitelisted {
        require(status == Status.Locked, "Fund is not locked");
        status = Status.Issued;
        // issuanceCycle.issuanceDate = block.timestamp;
        // burn the token of the expired issuance
        for (uint256 i = 0; i < investors.length; i++) {
            uint256 prevSupply = ISHNFT(shNFT).balanceOf(msg.sender, prevTokenId);
            if (prevSupply > 0) {
                ISHNFT(shNFT).burn(msg.sender, prevTokenId, prevSupply);
                ISHNFT(shNFT).mint(msg.sender, currentTokenId, prevSupply, issuanceCycle.uri);
            }
            uint256 tokenSupply = ISHNFT(shNFT).balanceOf(investors[i], currentTokenId);
            if (tokenSupply == 0 && userInfo[investors[i]].coupon == 0 && userInfo[investors[i]].optionPayout == 0) {
                investors.remove(i);
            }
        }
    }

    function mature() external onlyIssued onlyWhitelisted {
        status = Status.Mature;
        // issuanceCycle.maturityDate = block.timestamp;
    }

    /**
     * @dev Transfers option profit from a deribit wallet, called by an owner
     */
    function redeemOptionPayout(uint256 _optionProfit) external onlyQredo onlyMature {
        IERC20Upgradeable(currency).safeTransferFrom(msg.sender, address(this), _optionProfit);
        optionProfit = _optionProfit;

        emit RedeemOptionPayout(msg.sender, _optionProfit);
    }

    /**
     * @dev Update users' coupon balance every week
     */
    function weeklyCoupon() external onlyIssued onlyWhitelisted {
        for (uint256 i = 0; i < investors.length; i++) {
            uint256 tokenSupply = ISHNFT(shNFT).balanceOf(investors[i], currentTokenId);
            if (tokenSupply > 0) {
                userInfo[investors[i]].coupon += _convertTokenToCurrency(tokenSupply) * issuanceCycle.coupon / 10000;
            }
        }
    }

    /**
     * @dev Set new issuance cycle, called by a factory contract.
     */
    function setIssuanceCycle(
        IssuanceCycle calldata _issuanceCycle
    ) external onlyOwner {
        require(status != Status.Issued, "Already issued status");
        issuanceCycle = _issuanceCycle;
    }
    
    /**
     * @dev Deposits the USDC into the structured product and mint ERC1155 NFT
     * @param _amount is the amount of USDC to deposit
     */
    function deposit(uint256 _amount) external nonReentrant onlyAccepted {
        require(_amount > 0, "Amount must be greater than zero");
        uint256 decimals = _currencyDecimals();
        require((_amount % (1000 * 10 ** decimals)) == 0, "Amount must be whole-number thousands");
        
        uint256 supply = _amount / (1000 * 10 ** decimals);

        currentCapacity += _amount;
        require((maxCapacity * 10 ** decimals) >= currentCapacity, "Product is full");

        IERC20Upgradeable(currency).safeTransferFrom(msg.sender, address(this), _amount);
        ISHNFT(shNFT).mint(msg.sender, currentTokenId, supply, issuanceCycle.uri);

        investors.push(msg.sender);

        emit Deposit(msg.sender, _amount, currentTokenId, supply);
    }

    /**
     * @dev Withdraws the principal from the structured product
     */
    function withdrawPrincipal() external nonReentrant onlyAccepted {
        uint256 tokenSupply = ISHNFT(shNFT).balanceOf(msg.sender, prevTokenId);
        require(tokenSupply > 0, "No principal");
        uint256 principal = _convertTokenToCurrency(tokenSupply);
        require(totalBalance() >= principal, "Insufficient balance");
        
        IERC20Upgradeable(currency).safeTransfer(msg.sender, principal);
        ISHNFT(shNFT).burn(msg.sender, prevTokenId, tokenSupply);
        
        if (userInfo[msg.sender].coupon == 0 && userInfo[msg.sender].optionPayout == 0) {
            delete userInfo[msg.sender];
        }

        emit WithdrawPrincipal(msg.sender, principal, prevTokenId, tokenSupply);
    }

    /**
     * @notice Withdraws user's coupon payout
     */
    function withdrawCoupon() external nonReentrant onlyAccepted {
        require(totalBalance() >= userInfo[msg.sender].coupon,
            "Insufficient balance");
        if (userInfo[msg.sender].coupon > 0) {
            IERC20Upgradeable(currency).safeTransfer(msg.sender, userInfo[msg.sender].coupon);
            emit WithdrawCoupon(msg.sender, userInfo[msg.sender].coupon);
        }
    }

    /**
     * @notice Withdraws user's option payout
     */
    function withdrawOption() external nonReentrant onlyAccepted {
        require(totalBalance() >= userInfo[msg.sender].optionPayout,
            "Insufficient balance");
        if (userInfo[msg.sender].optionPayout > 0) {
            IERC20Upgradeable(currency).safeTransfer(msg.sender, userInfo[msg.sender].optionPayout);
            emit WithdrawOption(msg.sender, userInfo[msg.sender].optionPayout);
        }
    }

    /**
     * @notice Returns the number of investors
     */
    function numOfInvestors() external view returns (uint256) {
        return investors.length;
    }

    /**
     * @notice Returns the user's principal balance
     * Before auto-rolling or fund lock, users can have both tokens so total supply is the sum of 
     * previous supply and current supply
     */
    function principalBalance() external view returns (uint256) {
        uint256 prevSupply = ISHNFT(shNFT).balanceOf(msg.sender, prevTokenId);
        uint256 tokenSupply = ISHNFT(shNFT).balanceOf(msg.sender, currentTokenId);
        return _convertTokenToCurrency(prevSupply + tokenSupply);
    }

    /**
     * @notice Returns the user's coupon payout
     */
    function couponBalance() external view returns (uint256) {
        return userInfo[msg.sender].coupon;
    }

    /**
     * @notice Returns the user's option payout
     */
    function optionBalance() external view returns (uint256) {
        return userInfo[msg.sender].optionPayout;
    }

    /**
     * @notice Returns the product's total USDC balance
     */
    function totalBalance() public view returns (uint256) {
        return IERC20Upgradeable(currency).balanceOf(address(this));
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
     * @notice After the fund is locked, distribute USDC into the Qredo wallet and 
     * permissionless borrower poools of Clearpool protocol
     */
    function distribute(
        uint256 _optionRate, 
        uint256[] calldata _yieldRates, 
        address[] calldata _clearpools
    ) external onlyManager onlyIssued {
        require(!isDistributed, "Already distributed");
        require(_yieldRates.length == _clearpools.length, "Should have the same length");
        uint256 totalYieldRate = 0;
        for (uint256 i = 0; i < _yieldRates.length; i++) {
            totalYieldRate += _yieldRates[i];
        }
        require((totalYieldRate + _optionRate) <= 100, "Total percent should be equal or less than 100");
        
        // Transfer option amount to the Qredo wallet
        if (_optionRate > 0) {
            uint256 optionAmount = currentCapacity * _optionRate / 100;
            IERC20Upgradeable(currency).transfer(qredoDeribit, optionAmount);
        }

        // Lend into the clearpool
        for (uint256 i = 0; i < _clearpools.length; i++) {
            if (_yieldRates[i] > 0) {
                clearpools.push(_clearpools[i]);
                uint256 yieldAmount = currentCapacity * _yieldRates[i] / 100;
                IERC20Upgradeable(currency).approve(_clearpools[i], yieldAmount);
                IPoolMaster(_clearpools[i]).provide(yieldAmount);
            }
        }
        isDistributed = true;
        emit Distribute(qredoDeribit, _optionRate, _clearpools, _yieldRates);
    }

    function redeemYield() external onlyManager onlyMature {
        address[] memory _clearpools = clearpools;
        require(_clearpools.length > 0, "No yield source");
        for (uint256 i = 0; i < _clearpools.length; i++) {
            uint256 cpTokenBal = IPoolMaster(_clearpools[i]).balanceOf(address(this));
            IPoolMaster(_clearpools[i]).redeem(cpTokenBal);
        }
        uint256 redeemAmount = IERC20Upgradeable(currency).balanceOf(address(this));
        emit RedeemYield(_clearpools, redeemAmount);
    }
}
