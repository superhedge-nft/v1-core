// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { ethers, upgrades } = require("hardhat");

async function main() {
    // Deploy factory contract
    const SHFactory = await ethers.getContractFactory("SHFactory");
    const shFactory = await upgrades.deployProxy(SHFactory, []);
    await shFactory.deployed();

    console.log(`SHFactory deployed at ${shFactory.address}`);

    /* const factoryAddr = "0xa8B68a1e2400Fe67984A2d4197a063c56b0d0771";
    const SHFactory = await ethers.getContractFactory("SHFactory");
    const shFactory = await upgrades.upgradeProxy(factoryAddr, SHFactory);
    console.log("SHFactory upgraded"); */

    // Deploy NFT contract
    const SHNFT = await ethers.getContractFactory("SHNFT");
    const shNFT = await upgrades.deployProxy(SHNFT, [
        "Superhedge NFT", "SHN", shFactory.address
    ]);
    await shNFT.deployed();

    console.log(`SHNFT deployed at ${shNFT.address}`);

    /* const nftAddr = "0x17638b30e5d8440CdBFbFF7609D2a1493CD9cb73";
    const SHNFT = await ethers.getContractFactory("SHNFT");
    const shNFT = await upgrades.upgradeProxy(nftAddr, SHNFT);
    console.log("SHNFT upgraded"); */
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
