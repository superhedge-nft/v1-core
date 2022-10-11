const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SHNFT test suite", function () {
    let shFactory, shNFT;
    let owner, owner2;
    before(async() => {
        [owner, owner2] = await ethers.getSigners();
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

    it("Set token URI", async () => {
        const uri = "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH";
        await expect(
            shNFT.connect(owner2).setTokenURI(1, uri)
        ).to.be.reverted;

        await expect(
            shNFT.setTokenURI(1, uri)
        ).to.be.revertedWith("ERC1155#uri: NONEXISTENT_TOKEN");
    });
});
