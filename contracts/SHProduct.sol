// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/ISHProduct.sol";
import "./interfaces/ISHNFT.sol";
import "./interfaces/IUSDC.sol";
import "./SHNFT.sol";
import "./libraries/Array.sol";

contract SHProduct is ISHProduct, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Array for address[];

    string public name;
    string public underlying;

    address public constant USDC = 0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b;
    /// @notice role in charge of status transition automation: Gelato Ops
    address public constant ops = 0x6c3224f9b3feE000A444681d5D45e4532D5BA531;
    address public qredoDeribit;

    uint256 public maxCapacity;
    uint256 public currentTokenId;
    uint256 public currentCapacity;
    uint256 optionProfit;
    
    Status public status;
    IssuanceCycle public issuanceCycle;

    address public shNFT;
    
    mapping(address => UserInfo) public userInfo;
    address[] public investors;
    
    /**
     * @dev Throws if called by any account other than the keeper.
     */
    modifier onlyOps() {
        require(msg.sender == ops, "OpsReady: onlyOps");
        _;
    }

    modifier onlyAccepted() {
        require(status == Status.Accepted, "Not accepted status");
        _;
    }

    modifier notIssued() {
        require(status != Status.Issued, "Issued status");
        _;
    }

    constructor(
        string memory _name,
        string memory _underlying,
        address _qredo_deribit,
        address _shNFT,
        uint256 _maxCapacity,
        IssuanceCycle memory _issuanceCycle
    ) {
        name = _name;
        underlying = _underlying;

        qredoDeribit = _qredo_deribit;
        maxCapacity = _maxCapacity;

        shNFT = _shNFT;
        issuanceCycle = _issuanceCycle;
    }

    function fundAccept() external onlyOps {
        status = Status.Accepted;
        currentCapacity = 0;
    }

    function fundLock() external onlyOps {
        status = Status.Locked;
    }

    function issuance() external onlyOps {
        status = Status.Issued;
        // issuanceCycle.issuanceDate = block.timestamp;
        // burn the token of the expired issuance
        for (uint256 i = 0; i < investors.length; i++) {
            uint256 tokenSupply = ISHNFT(shNFT).balanceOf(investors[i], currentTokenId);
            if (tokenSupply == 0 && userInfo[investors[i]].coupon == 0 && userInfo[investors[i]].optionPayout == 0) {
                investors.remove(i);
            }
            uint256 prevTokenId = currentTokenId - 1;
            uint256 prevSupply = ISHNFT(shNFT).balanceOf(msg.sender, prevTokenId);
            if (prevSupply > 0) {
                ISHNFT(shNFT).burn(msg.sender, prevTokenId, prevSupply);
                ISHNFT(shNFT).mint(msg.sender, currentTokenId, prevSupply, issuanceCycle.uri);
            }
        }
    }

    function mature() external onlyOps {
        status = Status.Mature;
        // issuanceCycle.maturityDate = block.timestamp;
        uint256 totalSupply = ISHNFT(shNFT).totalSupply(currentTokenId);
        if (optionProfit > 0) {
            for (uint256 i = 0; i < investors.length; i++) {
                uint256 tokenSupply = ISHNFT(shNFT).balanceOf(investors[i], currentTokenId);
                userInfo[msg.sender].optionPayout += tokenSupply * optionProfit / totalSupply;
            }
        }
    }

    function redeemOptionPayout(uint256 _optionProfit) external {
        IERC20(USDC).safeTransferFrom(msg.sender, address(this), _optionProfit);
        optionProfit = _optionProfit;

        emit RedeemOptionPayout(msg.sender, _optionProfit);
    }

    function weeklyCoupon() external onlyOps {
        for (uint256 i = 0; i < investors.length; i++) {
            uint256 tokenSupply = ISHNFT(shNFT).balanceOf(investors[i], currentTokenId);
            if (tokenSupply > 0) {
                userInfo[investors[i]].coupon += _calcCoupon(tokenSupply);
            }
        }
    }

    function setCurrentTokenId(uint256 _id) external {
        currentTokenId = _id;
    }

    function setIssuanceCycle(
        IssuanceCycle calldata _issuanceCycle
    ) external onlyOwner notIssued {
        issuanceCycle = _issuanceCycle;
    }
    
    /**
     * @dev Deposits the USDC into the structured product and mint ERC1155 NFT
     * @param _amount is the amount of USDC to deposit
     */
    function deposit(uint256 _amount) external nonReentrant onlyAccepted {
        require(_amount > 0, "Amount must be greater than zero");
        uint256 decimals = IUSDC(USDC).decimals();
        require((_amount % (1000 * 10 ** decimals)) == 0, "Amount must be whole-number thousands");
        
        uint256 supply = _amount / (1000 * 10 ** decimals);

        currentCapacity += _amount;
        require((maxCapacity * 10 ** decimals) >= currentCapacity, "Product is full");

        IERC20(USDC).safeTransferFrom(msg.sender, address(this), _amount);

        ISHNFT(shNFT).mint(msg.sender, currentTokenId, supply, issuanceCycle.uri);
        // userInfo[msg.sender].principal += _amount;
        investors.push(msg.sender);

        emit Deposit(msg.sender, _amount, currentTokenId, supply);
    }

    /**
     * @dev Withdraws the principal from the structured product
     */
    function withdrawPrincipal() external nonReentrant onlyAccepted {
        uint256 tokenSupply = ISHNFT(shNFT).balanceOf(msg.sender, currentTokenId);
        require(tokenSupply > 0, "No principal");
        uint256 principal = tokenSupply * 1000 * (10 ** _underlyingDecimals());
        require(totalBalance() >= principal, "Insufficient balance");
        
        IERC20(USDC).safeTransfer(msg.sender, principal);
        ISHNFT(shNFT).burn(msg.sender, currentTokenId, tokenSupply);
        
        if (userInfo[msg.sender].coupon == 0 && userInfo[msg.sender].optionPayout == 0) {
            delete userInfo[msg.sender];
        }

        emit WithdrawPrincipal(msg.sender, principal, currentTokenId, tokenSupply);
    }

    function withdrawCoupon() external nonReentrant onlyAccepted {
        require(totalBalance() >= userInfo[msg.sender].coupon,
            "Insufficient balance");
        if (userInfo[msg.sender].coupon > 0) {
            IERC20(USDC).safeTransfer(msg.sender, userInfo[msg.sender].coupon);
            emit WithdrawCoupon(msg.sender, userInfo[msg.sender].coupon);
        }
    }

    function withdrawOption() external nonReentrant onlyAccepted {
        require(totalBalance() >= userInfo[msg.sender].optionPayout,
            "Insufficient balance");
        if (userInfo[msg.sender].optionPayout > 0) {
            IERC20(USDC).safeTransfer(msg.sender, userInfo[msg.sender].optionPayout);
            emit WithdrawCoupon(msg.sender, userInfo[msg.sender].optionPayout);
        }
    }

    /**
     * @notice Returns the product's total balance
     */
    function totalBalance() public view returns (uint256) {
        return IERC20(USDC).balanceOf(address(this));
    }

    function principalBalance() external view returns (uint256) {
        uint256 tokenSupply = ISHNFT(shNFT).balanceOf(msg.sender, currentTokenId);
        return tokenSupply * 1000 * (10 ** _underlyingDecimals());
    }

    function couponBalance() external view returns (uint256) {
        return userInfo[msg.sender].coupon;
    }

    function optionBalance() external view returns (uint256) {
        return userInfo[msg.sender].optionPayout;
    }

    function _underlyingDecimals() internal view returns (uint256) {
        return IUSDC(USDC).decimals();
    }

    function _calcCoupon(uint256 _tokenSupply) internal view returns (uint256) {
        return _tokenSupply * 1000 * (10 ** _underlyingDecimals()) * issuanceCycle.coupon / 10000;
    }
}
