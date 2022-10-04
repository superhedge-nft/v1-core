// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISHNFT.sol";
import "./interfaces/ISHProduct.sol";
import "./SHProduct.sol";

/**
 * @notice factory contract to create new products(vaults)
 */
contract SHFactory is Ownable {
    /// @notice mapping from product name to product address 
    mapping(string => address) public getProduct;
    /// @notice Boolean check for if an address is an instrument
    mapping(address => bool) public isProduct;
    /// @notice array of products' addresses
    address[] public products;
    /// @notice ERC1155 NFT contract address

    event ProductCreated(
        string name, 
        string underlying,
        address indexed product,
        uint256 maxSupply
    );

    event IssuanceCycleSet(
        address indexed product,
        uint256 coupon,
        uint256 strikePrice1,
        uint256 strikePrice2
    );

    /**
     * @notice function to create new product(vault)
     * @param _name is the product name
     * @param _underlying is the underlying asset label
     * @param _qredo_deribit is the wallet address of Deribit trading platform
     * @param _maxCapacity is the maximum USDC amount that this product can accept
     * @param _issuanceCycle is the struct variable with issuance date, 
        maturiy date, coupon, strike1 and strke2
     */
    function createProduct(
        string calldata _name,
        string calldata _underlying,
        address _qredo_deribit,
        address _shNFT,
        uint256 _maxCapacity,
        ISHProduct.IssuanceCycle calldata _issuanceCycle        
    ) external onlyOwner {
        require(getProduct[_name] == address(0), "Product already exists");
        require((_maxCapacity % 1000) == 0, "Max capacity must be whole-number thousands");

        bytes32 salt = keccak256(abi.encodePacked(_name));
        // create new product contract
        address productAddr = address(new SHProduct{salt:salt}(
            _name,
            _underlying,
            _qredo_deribit,
            _shNFT,
            _maxCapacity,
            _issuanceCycle
        ));

        getProduct[_name] = productAddr;
        isProduct[productAddr] = true;
        products.push(productAddr);
        
        ISHNFT(_shNFT).addMinter(productAddr);
        _setIssuanceCycle(productAddr, _issuanceCycle);
        
        emit ProductCreated(_name, _underlying, productAddr, _maxCapacity);
    }

    function setIssuanceCycle(
        address _product, 
        ISHProduct.IssuanceCycle calldata _issuanceCycle
    ) external onlyOwner {
        _setIssuanceCycle(_product, _issuanceCycle);
    }

    function _setIssuanceCycle(
        address _product,
        ISHProduct.IssuanceCycle memory _issuanceCycle
    ) internal {

        address shNFT = ISHProduct(_product).shNFT();
        ISHNFT(shNFT).tokenIdIncrement();
        uint256 tokenId = ISHNFT(shNFT).currentTokenID();

        /* if (bytes(_issuanceCycle.uri).length != 0) {
            ISHNFT(shNFT).setTokenURI(tokenId, _issuanceCycle.uri);
        } */

        ISHProduct(_product).setCurrentTokenId(tokenId);
        ISHProduct(_product).setIssuanceCycle(_issuanceCycle);

        emit IssuanceCycleSet(
            _product,
            _issuanceCycle.coupon, 
            _issuanceCycle.strikePrice1, 
            _issuanceCycle.strikePrice2
        );
    }

    /**
     * @notice returns the number of products
     */
    function numOfProducts() external view returns (uint256) {
        return products.length;
    }
}
