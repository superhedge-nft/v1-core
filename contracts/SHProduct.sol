// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/ISHNFT.sol";
import "./SHNFT.sol";

contract SHProduct is ReentrancyGuard {
    using SafeERC20 for IERC20;

    string public name;
    string public underlying;

    address public constant USDC = 0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b;
    address public qredoDeribit;
    
    uint256 public tokenId;
    uint256 public coupon;
    uint256 public strikePrice1;
    uint256 public strikePrice2;
    uint256 public issuanceDate;
    uint256 public maturityDate;
    uint256 public immutable MAX_CAPACITY;

    ISHNFT public shNFT;

    event ShNFTCreated(
        address indexed _product,
        address indexed _shNFT
    );

    event Deposit(
        address _user,
        uint256 _amount
    );

    constructor(
        string memory _name,
        string memory _underlying,
        address _qredo_deribit,
        uint256 _coupon,
        uint256 _strikePrice1,
        uint256 _strikePrice2,
        uint256 _issuanceDate,
        uint256 _maturityDate,
        uint256 _maxCapacity,
        ISHNFT _shNFT
    ) {
        name = _name;
        underlying = _underlying;
        qredoDeribit = _qredo_deribit;
        coupon = _coupon;
        strikePrice1 = _strikePrice1;
        strikePrice2 = _strikePrice2;

        issuanceDate = _issuanceDate;
        maturityDate = _maturityDate;
        MAX_CAPACITY = _maxCapacity;

        shNFT = _shNFT;
    }

    function setTokenId(uint256 _tokenId) external {
        tokenId = _tokenId;
    }

    /**
     * @notice Deposits the USDC into the structured product and mint ERC1155 NFT
     * @param _amount is the amount of USDC to deposit
     */
    function deposit(uint256 _amount) external nonReentrant  {
        require(_amount > 0, "Amount must be greater than zero");
        uint256 supply = _amount % (1000 * 1 ether);
        require(supply == 0, "Amount must be whole-number thousands");

        IERC20(USDC).safeTransferFrom(msg.sender, address(this), _amount);

        shNFT.safeTransferFrom(address(this), msg.sender, tokenId, supply, "0x0");

        emit Deposit(msg.sender, _amount);
    }
}
