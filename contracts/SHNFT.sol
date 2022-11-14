// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

/**
 * @notice NFT Contract relevant to product issuance, inherting ERC1155 standard contract
 */
contract SHNFT is ERC1155Upgradeable, AccessControlUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    /// @notice Token ID, starts in 1
    CountersUpgradeable.Counter private tokenIds;

    /// @notice Contract name
    string public name;
    /// @notice Contract symbol
    string public symbol;

    /// @notice Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;
    /// @notice Mapping from token ID to owner address
    mapping(uint256 => address) public creators;
    /// @notice Mapping from token ID to supply
    mapping(uint256 => uint256) public tokenSupply;

    /// @notice Owner role for contract deployer
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    /// @notice Admin role to assign minter roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    /// @notice Minter role to mint & burn tokens, and increase token ID
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Event emitted when new token is minted
    event Mint(address _to, uint256 _id, uint256 _amount, string _uri);

    /// @notice Event emitted when new token is burned
    event Burn(address _from, uint256 _id, uint256 _amount);

    /**
     * @dev Initialize the name & symbol of token, and the address of factory contract
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _factory Address of factory contract
     */
    function initialize(
        string memory _name, 
        string memory _symbol,
        address _factory
    ) public initializer {
        __ERC1155_init("");
        __AccessControl_init();

        name = _name;
        symbol = _symbol;

        _setupRole(OWNER_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, _factory);
        _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
    }

    /**
     * @dev Returns the URI for a token ID
     * @param _id uint256 ID of the token to query
     * @return tokenURI string uri
     */
    function uri(uint256 _id) public view override returns (string memory) {
        require(_exists(_id), "ERC1155#uri: NONEXISTENT_TOKEN");
        return _tokenURIs[_id];
    }

    /**
     * @dev Returns the current token ID
     */
    function currentTokenID() public view returns (uint256) {
        return tokenIds.current();
    }

    /**
     * @dev Returns the total quantity for a token ID
     * @param _id uint256 ID of the token to query
     * @return amount of token in existence
     */
    function totalSupply(uint256 _id) public view returns (uint256) {
        return tokenSupply[_id];
    }

    /**
     * @dev Creates a new token type and assigns _supply to an address
     * @param _to owner address of the new token
     * @param _id ID of the token
     * @param _amount Optional amount to supply the first owner
     * @param _uri Optional URI for this token type
     */
    function mint(
        address _to,
        uint256 _id,
        uint256 _amount,
        string calldata _uri
    ) external onlyRole(MINTER_ROLE) {
        
        creators[_id] = msg.sender;

        if (bytes(_uri).length > 0) {
            _setTokenURI(_id, _uri);
            emit URI(_uri, _id);
        }
        _mint(_to, _id, _amount, bytes(""));

        tokenSupply[_id] += _amount;

        emit Mint(_to, _id, _amount, _uri);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `from`
     * @param _from owner address of the given token ID
     * @param _id ID of the token
     * @param _amount amount to be burned
     */
    function burn(
        address _from,
        uint256 _id,
        uint256 _amount
    ) external onlyRole(MINTER_ROLE) {
        delete creators[_id];
        _burn(_from, _id, _amount);
        tokenSupply[_id] -= _amount;

        emit Burn(_from, _id, _amount);
    }

    /**
     * @dev Increase token ID every issuance cycle
     */
    function tokenIdIncrement() external onlyRole(MINTER_ROLE) {
        tokenIds.increment();
    }

    /**
     * @dev External function to set the token URI of given token ID
     * @param _id ID of the token
     * @param _uri Optional URI for this token ID
     */
    function setTokenURI(
        uint256 _id, 
        string calldata _uri
    ) external onlyRole(OWNER_ROLE) {
        require(_exists(_id), "ERC1155#uri: NONEXISTENT_TOKEN");
        require(bytes(_uri).length > 0, "uri should not be an empty string");
        _setTokenURI(_id, _uri);
    }

    /**
     * @dev Returns whether the specified token exists by checking to see if it has a creator
     * @param _id uint256 ID of the token to query the existence of
     * @return bool whether the token exists
     */
    function _exists(uint256 _id) internal view returns (bool) {
        return creators[_id] != address(0);
    }

    /**
     * @dev Sets `tokenURI` as the tokenURI of `tokenId`.
     */
    function _setTokenURI(uint256 tokenId, string memory tokenURI)
        internal
        virtual
    {
        _tokenURIs[tokenId] = tokenURI;
        emit URI(uri(tokenId), tokenId);
    }

    /**
     * @dev Adds minter role to the product contract to mint ERC1155 token to the depositors
     * @param _account The address of product contract
     */
    function addMinter(
        address _account
    ) external onlyRole(ADMIN_ROLE) {
        grantRole(MINTER_ROLE, _account);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            AccessControlUpgradeable,
            ERC1155Upgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
