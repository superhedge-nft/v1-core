// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

library Array {
    function remove(address[] storage arr, uint256 index) internal {
        // Move the last element into the place to delete
        require(arr.length > 0, "Can't remove from empty array");
        arr[index] = arr[arr.length - 1];
        arr.pop();
    }
}
