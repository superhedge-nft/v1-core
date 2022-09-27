// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ISHProduct {
    /// @notice Struct representing issuance cycle
    struct IssuanceCycle {
        uint256 coupon;
        uint256 strikePrice1;
        uint256 strikePrice2;
        uint256 issuanceDate;
        uint256 maturityDate;
    }

    /// @notice Enum representing product status
    enum Status {
        Accepted,
        Locked,
        Issued,
        Mature
    }

    function deposit(uint256 _amount) external;
}
