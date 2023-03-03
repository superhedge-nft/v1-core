// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../interfaces/ISHProduct.sol"; 
import "../libraries/DataTypes.sol";

interface IAddressRegistry {
    function tokenRegistry() external view returns (address);

    function priceFeed() external view returns (address);
}

interface ITokenRegistry {
    function enabled(address) external view returns (bool);
}

interface IPriceFeed {
    function wETH() external view returns (address);

    function getPrice(address) external view returns (int256, uint8);
}

contract SHMarketplace is ERC1155HolderUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using AddressUpgradeable for address payable;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice Events for the contract
    event ItemListed(
        address indexed owner,
        address indexed nft,
        address indexed product,
        uint256 tokenId,
        uint256 quantity,
        address payToken,
        uint256 pricePerItem,
        uint256 startingTime,
        uint256 listingId
    );

    event ItemUpdated(
        address indexed owner,
        address payToken,
        uint256 newPrice,
        uint256 listingId
    );

    event ItemCanceled(
        address indexed owner,
        uint256 listingId
    );

    event ItemSold(
        address indexed seller,
        address indexed buyer,
        int256 unitPrice,
        uint256 listingId
    );

    event UpdatePlatformFee(uint16 platformFee);
    event UpdatePlatformFeeRecipient(address payable platformFeeRecipient);

    /// @notice Structure for listed items
    struct Listing {
        uint256 listingId;
        uint256 tokenId;
        uint256 quantity;
        uint256 pricePerItem;
        address nftAddress;
        address payToken;
        address owner;
        address productAddress;
        uint256 startingTime;
    }

    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

    /// @notice Platform fee
    uint16 public platformFee;

    /// @notice Platform fee receipient
    address payable public feeReceipient;

    mapping(uint256 => Listing) public listings;

    uint256 public nextListingId;

    /// @notice Address registry
    IAddressRegistry public addressRegistry;

    modifier isListed(
        uint256 _listingId,
        address _owner
    ) {
        Listing memory listedItem = listings[_listingId];
        require(listedItem.owner == _owner, "Not the owner");
        require(listedItem.quantity > 0, "not listed item");
        _;
    }

    /// @notice Contract initializer
    function initialize(address payable _feeRecipient, uint16 _platformFee)
        public
        initializer
    {
        platformFee = _platformFee;
        feeReceipient = _feeRecipient;
        nextListingId = 1;

        __ERC1155Holder_init();
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    /**
     * @notice Method for updating platform fee
     * @dev Only admin
     * @param _platformFee uint16 the platform fee to set
     */
    function updatePlatformFee(uint16 _platformFee) external onlyOwner {
        platformFee = _platformFee;
        emit UpdatePlatformFee(_platformFee);
    }

    /**
     * @notice Method for updating platform fee address
     * @dev Only admin
     * @param _platformFeeRecipient payable address the address to sends the funds to
     */
    function updatePlatformFeeRecipient(address payable _platformFeeRecipient)
        external
        onlyOwner
    {
        feeReceipient = _platformFeeRecipient;
        emit UpdatePlatformFeeRecipient(_platformFeeRecipient);
    }

    /**
     * @notice Update AddressRegistry contract
     * @dev Only admin
     */
    function updateAddressRegistry(address _registry) external onlyOwner {
        addressRegistry = IAddressRegistry(_registry);
    }

    /// @notice Method for listing NFT
    /// @param _nftAddress Address of NFT contract
    /// @param _productAddress Address of structured product
    /// @param _tokenId Token ID of NFT
    /// @param _quantity token amount to list (needed for ERC-1155 NFTs, set as 1 for ERC-721)
    /// @param _payToken Paying token
    /// @param _pricePerItem sale price for each item
    /// @param _startingTime scheduling for a future sale
    function listItem(
        address _nftAddress,
        address _productAddress,
        uint256 _tokenId,
        uint256 _quantity,
        address _payToken,
        uint256 _pricePerItem,
        uint256 _startingTime
    ) external nonReentrant {
        require(_pricePerItem > 0, "Price must be greater than 0");
        require(_quantity > 0, "Quantity must be greater than 0");

        if (IERC165Upgradeable(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155)) {
            IERC1155Upgradeable nft = IERC1155Upgradeable(_nftAddress);
            require(
                nft.balanceOf(_msgSender(), _tokenId) >= _quantity,
                "must hold enough nfts"
            );
            require(
                nft.isApprovedForAll(_msgSender(), address(this)),
                "item not approved"
            );
        } else {
            revert("invalid nft address");
        }
        // check if this product was issued
        _validStatus(_productAddress);

        // check if this payment token was registered
        _validPayToken(_payToken);

        Listing memory listing = listings[nextListingId];
        require(listing.quantity == 0, "Listing already exists");

        // Transfer NFT from caller to Marketplace
        IERC1155Upgradeable(_nftAddress).safeTransferFrom(
            _msgSender(),
            address(this),
            _tokenId,
            _quantity,
            bytes("")
        );

        listings[nextListingId] = Listing(
            nextListingId,
            _tokenId,
            _quantity,
            _pricePerItem,
            _nftAddress,
            _payToken,
            _msgSender(),
            _productAddress,
            _startingTime
        );

        emit ItemListed(
            _msgSender(),
            _nftAddress,
            _productAddress,
            _tokenId,
            _quantity,
            _payToken,
            _pricePerItem,
            _startingTime,
            nextListingId
        );

        nextListingId++;
    }

    /// @notice Method for updating listed NFT
    /// @param _listingId Unique ID of Listing
    /// @param _payToken payment token
    /// @param _newPrice New sale price for each item
    function updateListing(
        uint256 _listingId,
        address _payToken,
        uint256 _newPrice
    ) external isListed(_listingId, _msgSender()) {
        require(_newPrice > 0, "Price must be greater than 0");

        Listing storage listedItem = listings[_listingId];

        address _productAddress = listedItem.productAddress;

        _validStatus(_productAddress);

        _validPayToken(_payToken);

        listedItem.payToken = _payToken;
        listedItem.pricePerItem = _newPrice;

        emit ItemUpdated(
            _msgSender(),
            _payToken,
            _newPrice,
            _listingId
        );
    }

    /// @notice Method for canceling listed NFT
    function cancelListing(uint256 _listingId)
        external
        nonReentrant
        isListed(_listingId, _msgSender())
    {
        Listing memory listedItem = listings[_listingId];

        _validStatus(listedItem.productAddress);

        address _nftAddress = listedItem.nftAddress;

        // Transfer NFT from marketplace to seller again
        IERC1155Upgradeable(_nftAddress).safeTransferFrom(
            address(this),
            listedItem.owner,
            listedItem.tokenId,
            listedItem.quantity,
            bytes("")
        );

        delete listings[_listingId];

        emit ItemCanceled(
            listedItem.owner,
            _listingId
        );
    }

    /// @notice Method for buying listed NFT
    /// @param _listingId ID of Listing
    /// @param _payToken Address of payment token
    /// @param _owner Owner of Listing
    function buyItem(
        uint256 _listingId,
        address _payToken,
        address _owner
    ) external nonReentrant isListed(_listingId, _owner) {
        require(_msgSender() != _owner, "Buyer should be different from seller");
        Listing memory listedItem = listings[_listingId];

        require(block.timestamp >= listedItem.startingTime, "Item not buyable");
        require(listedItem.payToken == _payToken, "Invalid pay token");

        uint256 price = listedItem.pricePerItem * listedItem.quantity;
        uint256 feeAmount = price * platformFee / 1e3;

        IERC20Upgradeable(_payToken).safeTransferFrom(
            _msgSender(),
            feeReceipient,
            feeAmount
        );

        IERC20Upgradeable(_payToken).safeTransferFrom(
            _msgSender(),
            _owner,
            price - feeAmount
        );

        address _nftAddress = listedItem.nftAddress;

        // Transfer NFT from marketplace to buyer
        IERC1155Upgradeable(_nftAddress).safeTransferFrom(
            address(this),
            _msgSender(),
            listedItem.tokenId,
            listedItem.quantity,
            bytes("")
        );

        delete listings[_listingId];

        emit ItemSold(
            _owner,
            _msgSender(),
            getPrice(_payToken),
            _listingId
        );
    }

    /**
     @notice Method for getting price for pay token
     @param _payToken Paying token
     */
    function getPrice(address _payToken) public view returns (int256) {
        int256 unitPrice;
        uint8 decimals;
        IPriceFeed priceFeed = IPriceFeed(addressRegistry.priceFeed());

        if (_payToken == address(0)) {
            (unitPrice, decimals) = priceFeed.getPrice(priceFeed.wETH());
        } else {
            (unitPrice, decimals) = priceFeed.getPrice(_payToken);
        }
        if (decimals < 18) {
            unitPrice = unitPrice * (int256(10)**(18 - decimals));
        } else {
            unitPrice = unitPrice / (int256(10)**(decimals - 18));
        }

        return unitPrice;
    }

    function _validStatus(address _product) internal view {
        DataTypes.Status status = ISHProduct(_product).status();
        require(status == DataTypes.Status.Issued, "Product is not issued yet");
    }

    function _validPayToken(address _payToken) internal view {
        require(
            _payToken == address(0) ||
                (addressRegistry.tokenRegistry() != address(0) &&
                    ITokenRegistry(addressRegistry.tokenRegistry())
                        .enabled(_payToken)),
            "invalid pay token"
        );
    }
}
