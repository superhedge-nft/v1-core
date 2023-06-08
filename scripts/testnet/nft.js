// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { ethers, upgrades } = require("hardhat");

async function main() {
    // Factory contract address
    const factoryAddr = "0x132f98F50c030020fa01C54e72f470ae7374b87F";

    // Deploy NFT contract
    const SHNFT = await ethers.getContractFactory("SHNFT");
    const shNFT = await upgrades.deployProxy(SHNFT, [
        "Superhedge NFT", "SHN", factoryAddr
    ]);
    await shNFT.deployed();

    console.log(`SHNFT deployed at ${shNFT.address}`);

    /* const nftAddr = "0xC21d745013cB1A8fa6Fa6575D842524650f0F610";
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
