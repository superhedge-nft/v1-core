// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ISHProduct {
    /// @notice Struct representing issuance cycle
    struct IssuanceCycle {
        uint256 coupon;
        uint256 strikePrice1;
        uint256 strikePrice2;
    }

    /// @notice Enum representing product status
    enum Status {
        Accepted,
        Locked,
        Issued,
        Mature
    }

    function maxCapacity() external view returns (uint256);

    function shNFT() external view returns (address);

    function setIssuanceCycle(IssuanceCycle calldata _issuanceCycle) external;

    function deposit(uint256 _amount) external;

    function setTokenId(uint256 _tokenId) external;
}
