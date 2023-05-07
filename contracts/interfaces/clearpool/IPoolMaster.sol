// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IPoolMaster {
    
    enum State {
        Active,
        Warning,
        ProvisionalDefault,
        Default,
        Closed
    }
    
    /// @notice Function is used to provide liquidity for Pool in exchange for cpTokens
    /// @dev Approval for desired amount of currency token should be given in prior
    /// @param currencyAmount Amount of currency token that user want to provide
    function provide(uint256 currencyAmount) external;

    /// @notice Function is used to provide liquidity in exchange for cpTokens to the given address
    /// @dev Approval for desired amount of currency token should be given in prior
    /// @param currencyAmount Amount of currency token that user want to provide
    /// @param receiver Receiver of cpTokens
    function provideFor(uint256 currencyAmount, address receiver) external;

    /// @notice Function is used to redeem previously provided liquidity with interest, burning cpTokens
    /// @param tokens Amount of cpTokens to burn (MaxUint256 to burn maximal possible)
    function redeem(uint256 tokens) external;

    /// @notice Function is used to redeem previously provided liquidity with interest, burning cpTokens
    /// @param currencyAmount Amount of currency to redeem (MaxUint256 to redeem maximal possible)
    function redeemCurrency(uint256 currencyAmount) external;

    function manager() external view returns (address);

    function currency() external view returns (address);

    function borrows() external view returns (uint256);

    function reserves() external view returns (uint256);

    function getBorrowRate() external view returns (uint256);

    function getSupplyRate() external view returns (uint256);

    function poolSize() external view returns (uint256);

    function cash() external view returns (uint256);

    function interest() external view returns (uint256);

    function principal() external view returns (uint256);

    function state() external view returns (State);

    function withdrawReward(address account) external returns (uint256);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function balanceOf(address account) external view returns (uint256);
}
