// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
// import "./ShProduct.sol";

contract ShFactory is Ownable {

    event ProductCreated(
        address indexed _product,
        address _underlying,
        uint256 _coupon,
        uint256 _strikePrice1,
        uint256 _strikePrice2,
        uint256 _issuanceDate,
        uint256 _maturityDate
    );

    function createProduct(
        string memory _name,
        string memory _symbol,
        address _deribit,
        address _usdc,
        address _underlying,
        uint256 _coupon,
        uint256 _strikePrice1,
        uint256 _strikePrice2,
        uint256 _issuanceDate,
        uint256 _maturityDate
    ) external onlyOwner {

        emit ProductCreated(
            address(this), 
            _underlying, 
            _coupon, 
            _strikePrice1, 
            _strikePrice2, 
            _issuanceDate, 
            _maturityDate
        );
    }
}
