// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IShNFT.sol";
import "./interfaces/IShProduct.sol";
import "./ShNFT.sol";
import "./ShProduct.sol";

contract ShFactory is Ownable {

    mapping(string => address) public getProduct;
    address[] public products;

    IShNFT public shNFT;

    event ProductCreated(
        string name, 
        address indexed product,
        uint256 tokenId,
        uint256 maxSupply
    );

    constructor(
        string memory _nftName,
        string memory _nftSymbol
    ) {
        bytes32 salt = keccak256(abi.encodePacked(_nftName, _nftSymbol));

        ShNFT _shNFT = new ShNFT{salt : salt}(_nftName, _nftSymbol);
        shNFT = IShNFT(address(_shNFT));
    }

    function createProduct(
        string memory _name,
        string memory _underlying,
        address _qredo_derebit,
        uint256 _coupon,
        uint256 _strikePrice1,
        uint256 _strikePrice2,
        uint256 _issuanceDate,
        uint256 _maturityDate,
        uint256 _maxCapacity,
        IShNFT _shNFT
    ) external onlyOwner {
        require(getProduct[_name] == address(0), "Product already exists");
        bytes32 salt = keccak256(abi.encodePacked(_name));

        address productAddr = address(new ShProduct{salt:salt}(
            _name,
            _underlying,
            _qredo_derebit,
            _coupon,
            _strikePrice1,
            _strikePrice2,
            _issuanceDate,
            _maturityDate,
            _maxCapacity,
            _shNFT
        ));

        getProduct[_name] = productAddr;
        products.push(productAddr);
        
        uint256 maxSupply = _maxCapacity / (1000 * 1 ether);
        uint256 tokenId = shNFT.mint(productAddr, maxSupply, "");
        IShProduct(productAddr).setTokenId(tokenId);
        
        emit ProductCreated(_name, productAddr, tokenId, maxSupply);
    }

    function numOfProducts() external view returns (uint256) {
        return products.length;
    }
}
