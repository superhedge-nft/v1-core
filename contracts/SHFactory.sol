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
     * @param _uri is the token URI of current product
     * @param _qredo_deribit is the wallet address of Deribit trading platform
     * @param _maxCapacity is the maximum USDC amount that this product can accept
     * @param _issuanceCycle is the struct variable with issuance date, 
        maturiy date, coupon, strike1 and strke2
     */
    function createProduct(
        string calldata _name,
        string calldata _underlying,
        string calldata _uri,
        address _qredo_deribit,
        address _shNFT,
        uint256 _maxCapacity,
        ISHProduct.IssuanceCycle calldata _issuanceCycle        
    ) external onlyOwner {
        require(getProduct[_name] == address(0), "Product already exists");
        uint256 maxSupply = _maxCapacity % 1000;
        require(maxSupply == 0, "Max capacity must be whole-number thousands");

        bytes32 salt = keccak256(abi.encodePacked(_name));
        // create new product contract
        address productAddr = address(new SHProduct{salt:salt}(
            _name,
            _underlying,
            _qredo_deribit,
            _shNFT,
            address(this),
            _maxCapacity,
            _issuanceCycle
        ));

        getProduct[_name] = productAddr;
        isProduct[productAddr] = true;
        products.push(productAddr);
        
        setIssuanceCycle(productAddr, _issuanceCycle, _uri);
        
        emit ProductCreated(_name, productAddr, maxSupply);
    }

    function setIssuanceCycle(
        address _product,
        ISHProduct.IssuanceCycle calldata _issuanceCycle,
        string memory _uri
    ) public onlyOwner {
        ISHProduct(_product).setIssuanceCycle(_issuanceCycle);
        uint256 maxCapacity = ISHProduct(_product).maxCapacity();
        uint256 maxSupply = maxCapacity / 1000;

        address shNFT = ISHProduct(_product).shNFT();
        ISHNFT(shNFT).mint(_product, maxSupply,_uri);

        uint256 tokenId = ISHNFT(shNFT).getCurrentTokenID();
        ISHProduct(_product).setTokenId(tokenId);

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
