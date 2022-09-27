// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SHNFT is ERC1155, Ownable {
    using Counters for Counters.Counter;
    /// @notice token ID, starts in 1
    Counters.Counter private tokenIds;

    /// @notice Contract name
    string public name;
    /// @notice Contract symbol
    string public symbol;

    /// @notice Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;
    /// @notice mapping from token ID to owner address
    mapping(uint256 => address) public creators;
    /// @notice mapping from token ID to supply
    mapping(uint256 => uint256) public tokenSupply;

    constructor(
        string memory _name, 
        string memory _symbol
    ) ERC1155("") {
        name = _name;
        symbol = _symbol;
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
    function getCurrentTokenID() public view returns (uint256) {
        return tokenIds.current();
    }

    /**
     * @dev Returns whether the specified token exists by checking to see if it has a creator
     * @param _id uint256 ID of the token to query the existence of
     * @return bool whether the token exists
     */
    function _exists(uint256 _id) public view returns (bool) {
        return creators[_id] != address(0);
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
     * @param _amount Optional amount to supply the first owner
     * @param _uri Optional URI for this token type
     */
    function mint(
        address _to,
        uint256 _amount,
        string calldata _uri
    ) external onlyOwner {
        tokenIds.increment();
        
        uint256 _id = tokenIds.current();
        creators[_id] = msg.sender;

        _setTokenURI(_id, _uri);

        if (bytes(_uri).length > 0) {
            emit URI(_uri, _id);
        }
        _mint(_to, _id, _amount, bytes(""));

        tokenSupply[_id] = _amount;
    }

    /**
     * @dev External function to set the token URI of given token ID
     * @param _id ID of the token
     * @param _uri Optional URI for this token ID
     */
    function setTokenURI(
        uint256 _id, 
        string calldata _uri
    ) external onlyOwner {
        _setTokenURI(_id, _uri);
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
}
