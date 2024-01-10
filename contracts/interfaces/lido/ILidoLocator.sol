// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ILidoLocator {
    function lido() external view returns(address);
    function withdrawalQueue() external view returns(address);
}