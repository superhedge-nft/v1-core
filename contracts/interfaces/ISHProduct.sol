// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ISHProduct {
    struct UserInfo {
        uint256 coupon;
        uint256 optionPayout;
    }
    
    /// @notice Struct representing issuance cycle
    struct IssuanceCycle {
        uint256 coupon;
        uint256 strikePrice1;
        uint256 strikePrice2;
        uint256 strikePrice3;
        uint256 strikePrice4;
        string uri;
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
        address indexed _from,
        uint256 _amount,
        uint256 _currentTokenId,
        uint256 _supply
    );

    event WithdrawPrincipal(
        address indexed _to,
        uint256 _amount,
        uint256 _currentTokenId,
        uint256 _amountToBurn
    );

    event WithdrawCoupon(
        address indexed _to,
        uint256 _amount
    );

    event WithdrawOption(
        address indexed _to,
        uint256 _amount
    );

    event RedeemOptionPayout(
        address indexed _from,
        uint256 _amount
    );

    event DistributeWithClear(
        address indexed _qredoDeribit,
        uint256 _optionRate,
        address[] _clearpools,
        uint256[] _yieldRates
    );

    event DistributeWithComp(
        address indexed _qredoDeribit,
        uint256 _optionRate,
        address indexed _cErc20Pool,
        uint256 _yieldRate
    );

    event RedeemYieldFromClear(
        address[] _clearpools
    );
    
    event RedeemYieldFromComp(
        address _cErc20Pool
    );

    function maxCapacity() external view returns (uint256);

    function shNFT() external view returns (address);

    function setIssuanceCycle(IssuanceCycle calldata _issuanceCycle) external;

    function deposit(uint256 _amount) external;
}
