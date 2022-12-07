const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

const { parseUnits } = ethers.utils;

describe("SHMarketplace test suite", () => {
    let shNFT, shFactory, shProduct, mockUSDC;
    let shMarketplace, addressRegistry, tokenRegistry, priceFeed;
    let owner, qredoDeribit, feeRecipient;

    const platformFee = 5; // 0.5% of sales price
    const wETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

    before(async() => {
        [owner, qredoDeribit, feeRecipient, user1, user2] = await ethers.getSigners();

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

        const AddressRegistry = await ethers.getContractFactory("AddressRegistry");
        addressRegistry = await upgrades.deployProxy(AddressRegistry, []);
        await addressRegistry.deployed();

        const SHMarketplace = await ethers.getContractFactory("SHMarketplace");
        shMarketplace = await upgrades.deployProxy(SHMarketplace, [
            feeRecipient.address, platformFee
        ]);
        await shMarketplace.deployed();

        const TokenRegistry = await ethers.getContractFactory("TokenRegistry");
        tokenRegistry = await upgrades.deployProxy(TokenRegistry, []);
        await tokenRegistry.deployed();

        const PriceFeed = await ethers.getContractFactory("PriceFeed");
        priceFeed = await upgrades.deployProxy(PriceFeed, [
            addressRegistry.address, wETH
        ]);
        await priceFeed.deployed();

        await addressRegistry.updateMarketplace(shMarketplace.address);
        await addressRegistry.updateTokenRegistry(tokenRegistry.address);
        await addressRegistry.updatePriceFeed(priceFeed.address);
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

        it("Product created", async() => {
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

    describe("List and update NFTs", () => {
        let currentTokenID, startingTime;
        before(async() => {
            await shMarketplace.connect(owner).updateAddressRegistry(addressRegistry.address);
            currentTokenID = await shProduct.currentTokenId();
            startingTime = Math.floor(Date.now() / 1000) + 1 * 24 * 3600;
        });

        it("Reverts unless the users hold enough nfts", async() => {
            await expect(shMarketplace.listItem(
                shNFT.address,
                currentTokenID,
                2,
                mockUSDC.address,
                parseUnits('1000', 6),
                startingTime
            )).to.be.revertedWith("must hold enough nfts");
        });

        it("Reverts if a nft is not approved", async() => {
            await expect(shMarketplace.connect(user1).listItem(
                shNFT.address,
                currentTokenID,
                2,
                mockUSDC.address,
                parseUnits('1000', 6),
                startingTime
            )).to.be.revertedWith("item not approved");
        });

        it("Invalid pay token", async() => {
            await shNFT.connect(user1).setApprovalForAll(shMarketplace.address, true);

            await expect(shMarketplace.connect(user1).listItem(
                shNFT.address,
                currentTokenID,
                2,
                mockUSDC.address,
                parseUnits('1000', 6),
                startingTime
            )).to.be.revertedWith("invalid pay token");
        });

        it("Successfully lists item", async() => {
            await tokenRegistry.connect(owner).add(mockUSDC.address);

            expect(await shMarketplace.connect(user1).listItem(
                shNFT.address,
                currentTokenID,
                2,
                mockUSDC.address,
                parseUnits('1100', 6),
                startingTime
            )).to.be.emit(shMarketplace, "ItemListed").withArgs(
                user1.address, shNFT.address, currentTokenID, 2, mockUSDC.address, parseUnits('1100', 6), startingTime
            );
        });

        it("Reverts if an item was already listed", async() => {
            await expect(shMarketplace.connect(user1).listItem(
                shNFT.address,
                currentTokenID,
                2,
                mockUSDC.address,
                parseUnits('1100', 6),
                startingTime
            )).to.be.revertedWith("already listed");
        });

        it("Successfully updates item", async() => {
            const newPrice = parseUnits('1200', 6);
            expect(await shMarketplace.connect(user1).updateListing(
                shNFT.address,
                currentTokenID,
                mockUSDC.address,
                newPrice
            )).to.be.emit(shMarketplace, "ItemUpdated").withArgs(
                user1.address, shNFT.address, currentTokenID, mockUSDC.address, newPrice
            );
        });
    });

    describe("Buy NFTs", () => {
        let currentTokenID;
        before(async() => {
            currentTokenID = await shProduct.currentTokenId();
        });
        
        it("Reverts if an item is not buyable", async() => {
            await expect(
                shMarketplace.connect(user2).buyItem(
                    shNFT.address,
                    currentTokenID,
                    mockUSDC.address,
                    user1.address
                )
            ).to.be.revertedWith("item not buyable");
        });

        it("Successfully buys NFT", async() => {
            // fast-forward 2 days
            await ethers.provider.send('evm_increaseTime', [2 * 24 * 3600]);
            await ethers.provider.send('evm_mine');

            await mockUSDC.mint(user2.address, parseUnits("10000", 6));

            await mockUSDC
                .connect(user2)
                .approve(shMarketplace.address, parseUnits("10000", 6));

            expect(
                await shMarketplace.connect(user2).buyItem(
                    shNFT.address,
                    currentTokenID,
                    mockUSDC.address,
                    user1.address
                )
            ).to.be.emit(shMarketplace, "ItemSold");
        })
    });
});
