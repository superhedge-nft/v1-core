// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

contract SHProduct {
    address public immutable USDC;

    constructor(address _usdc) {
        USDC = _usdc;
    }
}
