// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISHNFT.sol";
import "./interfaces/ISHProduct.sol";
import "./SHNFT.sol";
import "./SHProduct.sol";

contract SHFactory is Ownable {

    mapping(string => address) public getProduct;
    address[] public products;

    ISHNFT public shNFT;

    event NFTCreated(
        address indexed nft,
        string name,
        string symbol
    );

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

        SHNFT _shNFT = new SHNFT{salt : salt}(_nftName, _nftSymbol);
        shNFT = ISHNFT(address(_shNFT));

        emit NFTCreated(address(_shNFT), _nftName, _nftSymbol);
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
        ISHNFT _shNFT
    ) external onlyOwner {
        require(getProduct[_name] == address(0), "Product already exists");
        bytes32 salt = keccak256(abi.encodePacked(_name));
        // create new product contract
        address productAddr = address(new SHProduct{salt:salt}(
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
        
        // max supply of product NFT token
        uint256 maxSupply = _maxCapacity / 1000;
        shNFT.mint(productAddr, maxSupply, "");
        uint256 tokenId = shNFT.getCurrentTokenID();

        ISHProduct(productAddr).setTokenId(tokenId);
        
        emit ProductCreated(_name, productAddr, tokenId, maxSupply);
    }

    function numOfProducts() external view returns (uint256) {
        return products.length;
    }
}
