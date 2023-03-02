// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IMErc20 {
    function mint(uint mintAmount) external returns (uint);

    function redeem(uint redeemTokens) external returns (uint);

    function redeemUnderlying(uint redeemAmount) external returns (uint);

    function exchangeRateCurrent() external returns (uint);

    function exchangeRateStored() external view returns (uint);

    function supplyRatePerTimestamp() external returns (uint256);

    function balanceOf(address owner) external view returns (uint);
    
    function balanceOfUnderlying(address owner) external returns (uint);
}
