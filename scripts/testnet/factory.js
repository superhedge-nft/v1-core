// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { ethers, upgrades } = require("hardhat");

async function main() {
    // Deploy factory contract
    /* const SHFactory = await ethers.getContractFactory("SHFactory");
    const shFactory = await upgrades.deployProxy(SHFactory, []);
    await shFactory.deployed();

    console.log(`SHFactory deployed at ${shFactory.address}`); */

    const factoryAddr = "0x0D09452E92FcF098dAe6152fC27c9ea8424C8559";
    const SHFactory = await ethers.getContractFactory("SHFactory");
    const shFactory = await upgrades.upgradeProxy(factoryAddr, SHFactory);
    console.log("SHFactory upgraded");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
