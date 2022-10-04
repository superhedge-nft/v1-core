const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SHNFT test suite", function () {
    let shFactory, shNFT;
    before(async() => {
        const SHFactory = await ethers.getContractFactory("SHFactory");
        shFactory = await SHFactory.deploy();
        await shFactory.deployed();

        const SHNFT = await ethers.getContractFactory("SHNFT");
        shNFT = await SHNFT.deploy(
        "Superhedge NFT", "SHN", shFactory.address
        );
        await shNFT.deployed();
    });

    it("Returrns current token ID", async() => {
        expect(await shNFT.currentTokenID()).to.equal(0);
    });

    it("Reverts if token ID does not exist", async() => {
        await expect(
            shNFT.uri(1)
        ).to.be.revertedWith("ERC1155#uri: NONEXISTENT_TOKEN");
    });

    it("Returns total quantity for a token ID", async() => {
        expect(await shNFT.tokenSupply(1)).to.equal(0);
    });
});
