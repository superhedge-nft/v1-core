// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ISHProduct {
    struct UserInfo {
        uint256 principal;
        uint256 coupon;
        uint256 optionPayout;
    }
    
    /// @notice Struct representing issuance cycle
    struct IssuanceCycle {
        uint256 coupon;
        uint256 strikePrice1;
        uint256 strikePrice2;
        string uri;
        uint256 issuanceDate;
        uint256 maturityDate;
    }

    /// @notice Enum representing product status
    enum Status {
        Pending,
        Accepted,
        Locked,
        Issued,
        Mature
    }

    event Deposit(
        address _from,
        uint256 _amount,
        uint256 _currentTokenId,
        uint256 _supply
    );

    event WithdrawPrincipal(
        address _to,
        uint256 _amount,
        uint256 _currentTokenId,
        uint256 _amountToBurn
    );

    event WithdrawCoupon(
        address _to,
        uint256 _amount
    );

    event WithdrawOption(
        address _to,
        uint256 _amount
    );

    function maxCapacity() external view returns (uint256);

    function shNFT() external view returns (address);

    function setIssuanceCycle(IssuanceCycle calldata _issuanceCycle) external;

    function deposit(uint256 _amount) external;

    function setCurrentTokenId(uint256 _id) external;
}
