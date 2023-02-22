// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../libraries/DataTypes.sol";

interface ISHProduct {
    function maxCapacity() external view returns (uint256);

    function shNFT() external view returns (address);

    function deposit(uint256 _amount) external;

    function paused() external view returns (bool);

    function status() external view returns (DataTypes.Status);
}
