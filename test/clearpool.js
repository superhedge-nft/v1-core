const { expect } = require("chai");
const { ethers, upgrades, network } = require("hardhat");

describe("Clearpool integration test", () => {
    let usdc, poolMaster;
    let owner;

    const whaleAddress = "0xC882b111A75C0c657fC507C04FbFcD2cC984F071";
    const aurosPool = "0xB254554636a3ff52e8B2d0f06203921c137E10d5";
    const USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";

    before(async () => {
        [owner] = await ethers.getSigners();

        // unlock account
        await network.provider.send("hardhat_impersonateAccount", [whaleAddress]);

        usdc = await ethers.getContractAt("ERC20", USDC);

        console.log(usdc.address);

        poolMaster = await ethers.getContractAt(
            "PoolMaster",
            aurosPool
        );
    });
});
