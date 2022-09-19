// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IShNFT.sol";
import "./ShNFT.sol";

contract ShProduct is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public constant USDC = 0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b;
    address public qredoDeribit;
    
    uint256 public coupon;
    uint256 public strikePrice1;
    uint256 public strikePrice2;
    uint256 public issuanceDate;
    uint256 public maturityDate;
    uint256 public immutable MAX_CAPACITY;

    string public underlying;

    IShNFT public shNFT;

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
        string memory _symbol,
        string memory _underlying,
        address _qredo_deribit,
        uint256 _coupon,
        uint256 _strikePrice1,
        uint256 _strikePrice2,
        uint256 _issuanceDate,
        uint256 _maturityDate,
        uint256 _maxCapacity
    ) {
        underlying = _underlying;
        qredoDeribit = _qredo_deribit;
        coupon = _coupon;
        strikePrice1 = _strikePrice1;
        strikePrice2 = _strikePrice2;

        issuanceDate = _issuanceDate;
        maturityDate = _maturityDate;
        MAX_CAPACITY = _maxCapacity;

        bytes32 salt = keccak256(abi.encodePacked(_name, _symbol, address(this)));

        ShNFT _shNFT = new ShNFT{salt : salt}(_name, _symbol, address(this));
        shNFT = IShNFT(address(_shNFT));

        emit ShNFTCreated(address(this), address(_shNFT));
    }

    /**
     * @notice Deposits the USDC into the structured product and mint ERC1155 NFT
     * @param _amount is the amount of USDC to deposit
     */
    function deposit(uint256 _amount) external nonReentrant  {
        require(_amount > 0, "Amount must be greater than zero");
        require(_amount % (1000 * 1 ether) == 0, "Amount must be whole-number thousands");

        IERC20(USDC).safeTransfer(address(this), _amount);

        emit Deposit(msg.sender, _amount);
    }
}
