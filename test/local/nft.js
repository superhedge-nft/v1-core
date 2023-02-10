const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("SHNFT test suite", function () {
    let shFactory, shNFT;
    let owner, owner2;
    before(async() => {
        [owner, owner2] = await ethers.getSigners();
        const SHFactory = await ethers.getContractFactory("SHFactory");
        shFactory = await upgrades.deployProxy(SHFactory, []);
        await shFactory.deployed();

        const SHNFT = await ethers.getContractFactory("SHNFT");
        shNFT = await upgrades.deployProxy(SHNFT, [
            "Superhedge NFT", "SHN", shFactory.address
        ]);
        await shNFT.deployed();
    });

    it("Returrns current token ID", async() => {
        expect(await shNFT.currentTokenID()).to.equal(0);
    });

    it("Returns total quantity for a token ID", async() => {
        expect(await shNFT.totalSupply(1)).to.equal(0);
    });

    it("Set token URI", async () => {
        const uri = "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH";
        await expect(
            shNFT.connect(owner2).setTokenURI(1, uri)
        ).to.be.reverted;

        const tokenId = await shNFT.currentTokenID();
        expect(
            await shNFT.setTokenURI(tokenId, uri)
        ).to.emit(shNFT, "URI").withArgs(uri, tokenId);
    });

    it("Set owner role", async() => {
        expect(
            await shNFT.setRoleOwner(owner2.address)
        ).to.emit(shNFT, "RoleGranted");
    });
});
