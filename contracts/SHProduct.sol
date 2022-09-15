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
    
    IShNFT public shNFT;

    event ShNFTCreated(
        address indexed _product,
        address indexed _shNFT,
        string _name
    );

    event Deposit(
        address _user,
        uint256 _amount
    );

    constructor(
        string memory _name,
        string memory _underlying,
        address _qredo_derebit,
        uint256 _coupon,
        uint256 _strikePrice1,
        uint256 _strikePrice2,
        uint256 _issuanceDate,
        uint256 _maturityDate
    ) {
        qredoDeribit = _qredo_derebit;

        ShNFT _shNFT = new ShNFT(_name);
        shNFT = IShNFT(address(_shNFT));

        emit ShNFTCreated(address(this), address(_shNFT), _name);
    }

    /**
     * @notice Deposits the USDC into the structured product and mint ERC1155 NFT
     * @param _amount is the amount of USDC to deposit
     */
    function deposit(uint256 _amount) external nonReentrant  {
        require(_amount > 0, "invalid amount");
        IERC20(USDC).safeTransfer(address(this), _amount);

        emit Deposit(msg.sender, _amount);
    }
}
