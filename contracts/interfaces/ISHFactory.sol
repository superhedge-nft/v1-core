// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./ISHProduct.sol";

interface ISHFactory {
    function createProduct(
        string calldata _name,
        string calldata _underlying,
        IERC20Upgradeable _currency,
        address _manager,
        address _shNFT,
        address _qredo_deribit,
        uint256 _maxCapacity,
        ISHProduct.IssuanceCycle calldata _issuanceCycle        
    ) external;

    function setIssuanceCycle(
        address _product, 
        ISHProduct.IssuanceCycle calldata _issuanceCycle
    ) external;
    
    function numOfProducts() external view returns (uint256);

    function isProduct(address _product) external returns (bool);
}
