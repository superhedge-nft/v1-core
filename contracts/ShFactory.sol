// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ShProduct.sol";

contract ShFactory is Ownable {

    mapping(string => address) public getProduct;
    address[] public products;

    event ProductCreated(string _name, address indexed _product);

    function createProduct(
        string memory _name,
        string memory _symbol,
        string memory _underlying,
        address _qredo_derebit,
        uint256 _coupon,
        uint256 _strikePrice1,
        uint256 _strikePrice2,
        uint256 _issuanceDate,
        uint256 _maturityDate,
        uint256 _maxCapacity
    ) external onlyOwner {
        require(getProduct[_name] == address(0), "Product already exists");
        bytes32 salt = keccak256(abi.encodePacked(_name));

        address productAddr = address(new ShProduct{salt:salt}(
            _name,
            _symbol,
            _underlying,
            _qredo_derebit,
            _coupon,
            _strikePrice1,
            _strikePrice2,
            _issuanceDate,
            _maturityDate,
            _maxCapacity
        ));

        getProduct[_name] = productAddr;
        products.push(productAddr);
        
        emit ProductCreated(_name, productAddr);
    }

    function numOfProducts() external view returns (uint256) {
        return products.length;
    }
}
