// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./ISHProduct.sol";

interface ISHFactory {
    function createProduct(
        string calldata _name,
        string calldata _underlying,
        address _qredo_deribit,
        address _shNFT,
        uint256 _maxCapacity,
        ISHProduct.IssuanceCycle calldata _issuanceCycle        
    ) external;

    function numOfProducts() external view returns (uint256);

    function isProduct(address _product) external returns (bool);
}
