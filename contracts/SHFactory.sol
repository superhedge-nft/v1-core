// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/ISHNFT.sol";
import "./interfaces/ISHProduct.sol";
import "./interfaces/ISHFactory.sol";
import "./SHProduct.sol";

/**
 * @notice Factory contract to create new products
 */
contract SHFactory is ISHFactory, OwnableUpgradeable {

    /// @notice Array of products' addresses
    address[] public products;
    /// @notice Mapping from product name to product address 
    mapping(string => address) public getProduct;
    /// @notice Boolean check if an address is a product
    mapping(address => bool) public isProduct;

    /// @notice Event emitted when new product is created
    event ProductCreated(
        address indexed product,
        string name, 
        string underlying,
        uint256 maxSupply
    );

    /// @notice Event emitted when new issuance cycle is set
    event IssuanceCycleSet(
        address indexed product,
        uint256 coupon,
        uint256 strikePrice1,
        uint256 strikePrice2,
        uint256 strikePrice3,
        uint256 strikePrice4,
        string uri
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function initialize() public initializer {
        __Ownable_init();
    }

    /**
     * @notice Function to create new product(vault)
     * @param _name is the product name
     * @param _underlying is the underlying asset label
     * @param _currency principal asset, USDC address
     * @param _manager manager of the product
     * @param _qredo_deribit is the wallet address of Deribit trading platform
     * @param _maxCapacity is the maximum USDC amount that this product can accept
     * @param _issuanceCycle is the struct variable with issuance date, 
        maturiy date, coupon, strike1 and strke2
     */
    function createProduct(
        string calldata _name,
        string calldata _underlying,
        IERC20Upgradeable _currency,
        address _manager,
        address _shNFT,
        address _qredo_deribit,
        uint256 _maxCapacity,
        ISHProduct.IssuanceCycle calldata _issuanceCycle        
    ) external onlyOwner {
        require(getProduct[_name] == address(0), "Product already exists");
        require((_maxCapacity % 1000) == 0, "Max capacity must be whole-number thousands");

        // create new product contract
        SHProduct product = new SHProduct();
        product.initialize(
            _name, 
            _underlying, 
            _currency,
            _manager,
            _shNFT, 
            _qredo_deribit, 
            _maxCapacity, 
            _issuanceCycle
        );
        address productAddr = address(product);

        getProduct[_name] = productAddr;
        isProduct[productAddr] = true;
        products.push(productAddr);
        // add NFT minter role
        ISHNFT(_shNFT).addMinter(productAddr);
        _setIssuanceCycle(productAddr, _issuanceCycle);
        
        emit ProductCreated(productAddr, _name, _underlying, _maxCapacity);
    }

    /**
     * @notice Set new issuance cycle by owner
     */
    function setIssuanceCycle(
        address _product, 
        ISHProduct.IssuanceCycle calldata _issuanceCycle
    ) external onlyOwner {
        _setIssuanceCycle(_product, _issuanceCycle);
    }

    /**
     * @notice returns the number of products
     */
    function numOfProducts() external view returns (uint256) {
        return products.length;
    }

    /**
     * @notice Internal function to set issuance cycle
     */
    function _setIssuanceCycle(
        address _product,
        ISHProduct.IssuanceCycle memory _issuanceCycle
    ) internal {
        require(isProduct[_product], "Product does not exist");
        ISHProduct(_product).setIssuanceCycle(_issuanceCycle);

        emit IssuanceCycleSet(
            _product,
            _issuanceCycle.coupon, 
            _issuanceCycle.strikePrice1, 
            _issuanceCycle.strikePrice2,
            _issuanceCycle.strikePrice3,
            _issuanceCycle.strikePrice4,
            _issuanceCycle.uri
        );
    }
}
