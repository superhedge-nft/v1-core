// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library DataTypes {
    /// @notice Struct representing issuance cycle
    struct IssuanceCycle {
        uint256 coupon;
        uint256 strikePrice1;
        uint256 strikePrice2;
        uint256 strikePrice3;
        uint256 strikePrice4;
        string uri;
    }
}
