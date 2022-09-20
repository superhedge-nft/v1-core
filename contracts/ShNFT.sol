// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ShNFT is ERC1155Supply, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    // Contract name
    string public name;

    // Contract symbol
    string public symbol;

    constructor(
        string memory _name, 
        string memory _symbol
    ) ERC1155("") {
        name = _name;
        symbol = _symbol;

        tokenIds.increment();
    }

    function uri(uint256 _id) public view override returns (string memory) {
        require(exists(_id), "ERC1155#uri: NONEXISTENT_TOKEN");
        return _tokenURIs[_id];
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
    ) external onlyOwner returns (uint256) {
        uint256 _id = tokenIds.current();

        _setTokenURI(_id, _uri);

        if (bytes(_uri).length > 0) {
            emit URI(_uri, _id);
        }

        _mint(_to, _id, _amount, bytes(""));

        tokenIds.increment();
        return _id;
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
