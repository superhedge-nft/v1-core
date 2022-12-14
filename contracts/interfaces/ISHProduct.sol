// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ISHProduct {
    function maxCapacity() external view returns (uint256);

    function shNFT() external view returns (address);

    function deposit(uint256 _amount) external;

    function paused() external view returns (bool);
}
