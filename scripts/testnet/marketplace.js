// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { ethers, upgrades } = require("hardhat");

async function main() {
    // Deploy AddressRegistry contract
    const AddressRegistry = await ethers.getContractFactory("AddressRegistry");
    const addressRegistry = await upgrades.deployProxy(AddressRegistry, []);
    await addressRegistry.deployed();

    console.log(`AddressRegistry deployed at ${addressRegistry.address}`);

    // Deploy PriceFeed contract
    const wETH = "0x65a0655d38fb6cc03c59aadd7f79e658ccc9d3fb";
    const PriceFeed = await ethers.getContractFactory("PriceFeed");
    const priceFeed = await upgrades.deployProxy(PriceFeed, [
        addressRegistry.address, wETH
    ]);
    await priceFeed.deployed();

    console.log(`PriceFeed deployed at ${priceFeed.address}`);

    // Deploy TokenRegistry contract
    const TokenRegistry = await ethers.getContractFactory("TokenRegistry");
    const tokenRegistry = await upgrades.deployProxy(TokenRegistry, []);
    await tokenRegistry.deployed();

    console.log(`TokenRegistry deployed at ${tokenRegistry.address}`);

    const platformFee = 5; // 0.5% of sales price
    const feeRecipient = "0x6Ca8304ae1973C205c6ac9A6Fb82a017cA800e77";

    const SHMarketplace = await ethers.getContractFactory("SHMarketplace");
    const shMarketplace = await upgrades.deployProxy(SHMarketplace, [
        feeRecipient, platformFee
    ]);
    await shMarketplace.deployed();

    console.log(`SHMarketplace deployed at ${shMarketplace.address}`);

    await addressRegistry.updateMarketplace(shMarketplace.address);

    await addressRegistry.updateTokenRegistry(tokenRegistry.address);

    await addressRegistry.updatePriceFeed(priceFeed.address);

    const paymentToken = "0xb5ca840de205cdf0757681fdbf17e528dc4433cf";
    
    await tokenRegistry.add(paymentToken);

    await tokenRegistry.add(wETH);

    await shMarketplace.updateAddressRegistry(addressRegistry.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
