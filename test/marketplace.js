const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

const { parseUnits } = ethers.utils;

describe("SHMarketplace test suite", () => {
    let shMarketplace, shNFT, shFactory, shProduct, mockUSDC;
    let owner, qredoDeribit, feeRecipient;

    const platformFee = ethers.BigNumber.from('5'); // 0.5% of sales price

    before(async() => {
        [owner, qredoDeribit, feeRecipient, user1] = await ethers.getSigners();

        const SHFactory = await ethers.getContractFactory("SHFactory");
        shFactory = await upgrades.deployProxy(SHFactory, []);
        await shFactory.deployed();

        const SHNFT = await ethers.getContractFactory("SHNFT");
        shNFT = await upgrades.deployProxy(SHNFT, [
            "Superhedge NFT", "SHN", shFactory.address
        ]);
        await shNFT.deployed();

        const MockUSDC = await ethers.getContractFactory("MockUSDC");
        mockUSDC = await MockUSDC.deploy();
        await mockUSDC.deployed();

        const SHMarketplace = await ethers.getContractFactory("SHMarketplace");
        shMarketplace = await upgrades.deployProxy(SHMarketplace, [
            feeRecipient.address, platformFee
        ]);
        await shMarketplace.deployed();
    });

    describe("Create product", () => {
        const productName = "BTC Defensive Spread";
        const tokenURI = "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH";

        const issuanceCycle = {
            coupon: 10,
            strikePrice1: 25000,
            strikePrice2: 20000,
            strikePrice3: 0,
            strikePrice4: 0,
            uri: tokenURI
        }

        it("product created", async() => {
            expect(await shFactory.createProduct(
                productName,
                "BTC/USD",
                mockUSDC.address,
                owner.address,
                shNFT.address,
                qredoDeribit.address,
                1000000,
                issuanceCycle
              )).to.be.emit(shFactory, "ProductCreated");

            // get product
            const productAddr = await shFactory.getProduct(productName);
            const SHProduct = await ethers.getContractFactory("SHProduct");
            shProduct = SHProduct.attach(productAddr);
        });

        it("User1 deposits 2000 USDC and receive NFT token", async() => {
            await mockUSDC.mint(user1.address, parseUnits("10000", 6));
            await shProduct.whitelist(owner.address);

            await shProduct.fundAccept();

            const amount = parseUnits("2000", 6);
            await mockUSDC.connect(user1).approve(shProduct.address, amount);

            expect(
                await shProduct.connect(user1).deposit(amount)
            ).to.be.emit(shProduct, "Deposit");
        });
    });

    describe("Listing NFT", () => {
        it("successfully lists item", async() => {
            const currentTokenID = await shProduct.currentTokenId();

            await shMarketplace.listItem(
                shNFT.address,
                currentTokenID,
                1,
                mockUSDC.address,
                parseUnits('1000', 6),
                (new Date().getTime() / 1000) + 7 * 24 * 3600
            );
        });
    });
});
