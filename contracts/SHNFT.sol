// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "./libraries/ERC1155EnumerableStorage.sol";

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
     * @dev Adds minter role to the product contract to mint ERC1155 token to the depositors
     * @param _account The address of product contract
     */
    function addMinter(
        address _account
    ) external onlyRole(ADMIN_ROLE) {
        grantRole(MINTER_ROLE, _account);
    }

    /**
     * @dev Sets owner role
     * @param _account The owner address
     */
    function setRoleOwner(
        address _account
    ) external onlyRole(OWNER_ROLE) {
        _grantRole(OWNER_ROLE, _account);
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

    /** ============= Customized ============= **/
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    /**
     * @dev IERC1155Enumerable
     */
    function totalSupply(uint256 _id)
        public
        view
        virtual
        returns (uint256)
    {
        return ERC1155EnumerableStorage.layout().totalSupply[_id];
    }

    /**
     * @dev IERC1155Enumerable
     */
    function totalHolders(uint256 _id)
        public
        view
        virtual
        returns (uint256)
    {
        return ERC1155EnumerableStorage.layout().accountsByToken[_id].length();
    }

    /**
     * @dev IERC1155Enumerable
     */
    function accountsByToken(uint256 _id)
        public
        view
        virtual
        returns (address[] memory)
    {
        EnumerableSetUpgradeable.AddressSet storage accounts = ERC1155EnumerableStorage
            .layout()
            .accountsByToken[_id];

        address[] memory addresses = new address[](accounts.length());

        for (uint256 i; i < accounts.length(); i++) {
            addresses[i] = accounts.at(i);
        }

        return addresses;
    }

    /**
     * @dev IERC1155Enumerable
     */
    function tokensByAccount(address _account)
        public
        view
        virtual
        returns (uint256[] memory)
    {
        EnumerableSetUpgradeable.UintSet storage tokens = ERC1155EnumerableStorage
            .layout()
            .tokensByAccount[_account];

        uint256[] memory ids = new uint256[](tokens.length());

        for (uint256 i; i < tokens.length(); i++) {
            ids[i] = tokens.at(i);
        }

        return ids;
    }

    /**
     * @notice ERC1155 hook: update aggregate values
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        if (from != to) {
            ERC1155EnumerableStorage.Layout storage l = ERC1155EnumerableStorage
                .layout();
            mapping(uint256 => EnumerableSetUpgradeable.AddressSet)
                storage tokenAccounts = l.accountsByToken;
            EnumerableSetUpgradeable.UintSet storage fromTokens = l.tokensByAccount[from];
            EnumerableSetUpgradeable.UintSet storage toTokens = l.tokensByAccount[to];

            for (uint256 i; i < ids.length; i++) {
                uint256 amount = amounts[i];

                if (amount > 0) {
                    uint256 id = ids[i];

                    if (from == address(0)) {
                        l.totalSupply[id] += amount;
                    } else if (balanceOf(from, id) == amount) {
                        tokenAccounts[id].remove(from);
                        fromTokens.remove(id);
                    }

                    if (to == address(0)) {
                        l.totalSupply[id] -= amount;
                    } else if (balanceOf(to, id) == 0) {
                        tokenAccounts[id].add(to);
                        toTokens.add(id);
                    }
                }
            }
        }
    }
}
