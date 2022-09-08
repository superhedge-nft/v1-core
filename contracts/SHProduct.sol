// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ShProduct is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable USDC;

    constructor(address _usdc) {
        USDC = _usdc;
    }

    /**
     * @notice Deposits the USDC into the structured product and mint ERC1155 NFT
     * @param _amount is the amount of USDC to deposit
     */
    function deposit(uint256 _amount) external nonReentrant {
        IERC20(USDC).safeTransfer(address(this), _amount);
    }
}
