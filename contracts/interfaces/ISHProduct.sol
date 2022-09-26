// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ISHProduct {
    function deposit(uint256 _amount) external;

    function setTokenId(uint256 _tokenId) external;
}
