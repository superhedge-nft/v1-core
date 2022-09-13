// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IShNFT {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function mint(address _to, uint256 _amount, string calldata _uri) external;
}
