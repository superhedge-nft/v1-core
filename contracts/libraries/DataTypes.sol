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
        uint256 tr1;
        uint256 tr2;
        uint256 issuanceDate;
        uint256 maturityDate;
        string apy;
        string uri;
    }
}
