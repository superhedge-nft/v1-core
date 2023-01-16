// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ISHNFT {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function balanceOf(address _account, uint256 _id) external view returns (uint256);

    function mint(address _to, uint256 _id, uint256 _amount, string calldata _uri) external;

    function burn(address _from, uint256 _id, uint256 _amount) external;

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) external;

    function currentTokenID() external view returns (uint256);

    function tokenIdIncrement() external;

    function totalSupply(uint256 _id) external view returns (uint256);

    function addMinter(address _account) external;

    function setTokenURI(uint256 _id, string calldata _uri) external;

    function accountsByToken(uint256 _id) external view returns (address[] memory);

    function tokensByAccount(address _account) external view returns (uint256[] memory);

    function totalHolders(uint256 _id) external view returns (uint256);
}
