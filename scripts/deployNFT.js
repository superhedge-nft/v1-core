// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { ethers } = require("hardhat");

async function main() {
    const factoryAddr = "0xac39D351089681a6116D19BE1df4Bf94DAdbCC4C";
    const SHNFT = await ethers.getContractFactory("SHNFT");
    const shNFT = await SHNFT.deploy(
        "Superhedge NFT", "SHN", factoryAddr
    );
    await shNFT.deployed();

    console.log(`SHNFT contract deployed at ${shNFT.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
