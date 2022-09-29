// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ISHNFT {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function mint(address _to, uint256 _id, uint256 _amount, string calldata _uri) external;

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) external;

    function getCurrentTokenID() external view returns (uint256);

    function tokenIdIncrement() external;

    function totalSupply(uint256 _id) external view returns (uint256);

    function addMinter(address _account) external;
}
