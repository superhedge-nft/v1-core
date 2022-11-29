// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract AddressRegistry is OwnableUpgradeable {

    /// @notice Marketplace contract
    address public marketplace;

    /// @notice TokenRegistry contract
    address public tokenRegistry;

    /// @notice PriceFeed contract
    address public priceFeed;

    function initialize() public initializer {
        __Ownable_init();
    }
    
    /**
     @notice Update FantomMarketplace contract
     @dev Only admin
     */
    function updateMarketplace(address _marketplace) external onlyOwner {
        marketplace = _marketplace;
    }

    /**
     @notice Update token registry contract
     @dev Only admin
     */
    function updateTokenRegistry(address _tokenRegistry) external onlyOwner {
        tokenRegistry = _tokenRegistry;
    }

    /**
     @notice Update price feed contract
     @dev Only admin
     */
    function updatePriceFeed(address _priceFeed) external onlyOwner {
        priceFeed = _priceFeed;
    }
}
