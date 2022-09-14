// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IShNFT.sol";
import "./ShNFT.sol";

contract ShProduct is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable USDC;
    address public deribit;

    IShNFT public shNFT;

    event ShNFTCreated(
        address indexed _product,
        address indexed _shNFT,
        string _name,
        string _symbol
    );

    event Deposit(
        address _user,
        uint256 _amount
    );

    constructor(
        address _usdc, 
        address _deribit, 
        string memory _name,
        string memory _symbol
    ) {
        USDC = _usdc;
        deribit = _deribit;

        ShNFT _shNFT = new ShNFT(_name, _symbol);
        shNFT = IShNFT(address(_shNFT));

        emit ShNFTCreated(address(this), address(_shNFT), _name, _symbol);
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
