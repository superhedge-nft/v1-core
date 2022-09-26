// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./ISHNFT.sol";

interface ISHFactory {
    function createProduct(
        string memory _name,
        string memory _underlying,
        address _qredo_deribit,
        uint256 _coupon,
        uint256 _strikePrice1,
        uint256 _strikePrice2,
        uint256 _issuanceDate,
        uint256 _maturityDate,
        uint256 _maxCapacity,
        ISHNFT _shNFT
    ) external;

    function numOfProducts() external view returns (uint256);

    function isProduct(address _product) external returns (bool);
}
