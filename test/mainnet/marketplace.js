const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

const { parseUnits } = ethers.utils;

describe("SHMarketplace test suite", () => {
    let shNFT, shFactory, shProduct, mockUSDC;
    let shMarketplace, addressRegistry, tokenRegistry, priceFeed;
    let owner, qredoDeribit, feeRecipient;

    const platformFee = 5; // 0.5% of sales price
    const wETH = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";

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
        const productName = "ETH Bullish Spread";
    
        const issuanceCycle = {
            coupon: 10,
            strikePrice1: 1400,
            strikePrice2: 1600,
            strikePrice3: 0,
            strikePrice4: 0,
            tr1: 11750,
            tr2: 10040,
            issuanceDate: Math.floor(Date.now() / 1000) + 7 * 86400,
            maturityDate: Math.floor(Date.now() / 1000) + 30 * 86400,
            apy: "7-15%",
            uri: "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH"
        }

        const qredoWallet = "0xbba1088BD130AF05AA0ab3EA89464F10C83B984A";

        it("Product created", async() => {
            expect(await shFactory.createProduct(
                productName,
                "ETH/USDC",
                mockUSDC.address,
                owner.address,
                shNFT.address,
                qredoWallet,
                100000,
                issuanceCycle
              )).to.be.emit(shFactory, "ProductCreated");
          
              expect(await shFactory.numOfProducts()).to.equal(1);
          
              // get product
              const productAddr = await shFactory.getProduct(productName);
              const SHProduct = await ethers.getContractFactory("SHProduct");
              shProduct = SHProduct.attach(productAddr);
        });

        it("User1 deposits 2000 USDC and receive NFT token", async() => {
            await mockUSDC.mint(user1.address, parseUnits("10000", 6));
            await shProduct.whitelist(owner.address);

            await shProduct.fundAccept();

            const amount = parseUnits("5000", 6);
            await mockUSDC.connect(user1).approve(shProduct.address, amount);

            expect(
                await shProduct.connect(user1).deposit(amount, false)
            ).to.be.emit(shProduct, "Deposit");
        });
    });

    describe("List and update NFTs", () => {
        let currentTokenID, startingTime, listingId;
        const quantity1 = 2;
        const quantity2 = 3;

        before(async() => {
            await shProduct.fundLock();
            await shProduct.issuance();

            await shMarketplace.connect(owner).updateAddressRegistry(addressRegistry.address);
            currentTokenID = await shProduct.currentTokenId();
            startingTime = Math.floor(Date.now() / 1000) + 300; // delta 5 mins
        });

        it("Reverts unless the users hold enough nfts", async() => {
            await expect(shMarketplace.listItem(
                shNFT.address,
                shProduct.address,
                currentTokenID,
                quantity1,
                mockUSDC.address,
                parseUnits('1000', 6),
                startingTime
            )).to.be.revertedWith("must hold enough nfts");
        });

        it("Reverts if a nft is not approved", async() => {
            await expect(shMarketplace.connect(user1).listItem(
                shNFT.address,
                shProduct.address,
                currentTokenID,
                quantity1,
                mockUSDC.address,
                parseUnits('1000', 6),
                startingTime
            )).to.be.revertedWith("item not approved");
        });

        it("Invalid pay token", async() => {
            await shNFT.connect(user1).setApprovalForAll(shMarketplace.address, true);

            await expect(shMarketplace.connect(user1).listItem(
                shNFT.address,
                shProduct.address,
                currentTokenID,
                quantity1,
                mockUSDC.address,
                parseUnits('1000', 6),
                startingTime
            )).to.be.revertedWith("invalid pay token");
        });

        it("Successfully lists item", async() => {
            await tokenRegistry.connect(owner).add(mockUSDC.address);

            listingId = await shMarketplace.nextListingId();

            expect(await shMarketplace.connect(user1).listItem(
                shNFT.address,
                shProduct.address,
                currentTokenID,
                quantity1,
                mockUSDC.address,
                parseUnits('1100', 6),
                startingTime
            )).to.be.emit(shMarketplace, "ItemListed").withArgs(
                user1.address, 
                shNFT.address, 
                shProduct.address, 
                currentTokenID, 
                quantity1, 
                mockUSDC.address, 
                parseUnits('1100', 6), 
                startingTime,
                listingId
            );

            expect(
                await shNFT.balanceOf(shMarketplace.address, currentTokenID)
            ).to.equal(quantity1);

            expect(
                await shNFT.balanceOf(user1.address, currentTokenID)
            ).to.equal(quantity2);
        });

        it("Successfully updates item", async() => {
            const newPrice = parseUnits('1200', 6);
            expect(await shMarketplace.connect(user1).updateListing(
                listingId,
                mockUSDC.address,
                newPrice
            )).to.be.emit(shMarketplace, "ItemUpdated").withArgs(
                user1.address, 
                mockUSDC.address, 
                newPrice,
                listingId
            );
        });

        it("Create another listing", async() => {
            listingId = await shMarketplace.nextListingId();

            expect(await shMarketplace.connect(user1).listItem(
                shNFT.address,
                shProduct.address,
                currentTokenID,
                quantity2,
                mockUSDC.address,
                parseUnits('1200', 6),
                startingTime
            )).to.be.emit(shMarketplace, "ItemListed").withArgs(
                user1.address, 
                shNFT.address, 
                shProduct.address, 
                currentTokenID, 
                quantity2, 
                mockUSDC.address, 
                parseUnits('1200', 6), 
                startingTime,
                listingId
            );

            expect(
                await shNFT.balanceOf(shMarketplace.address, currentTokenID)
            ).to.equal(quantity1 + quantity2);

            expect(
                await shNFT.balanceOf(user1.address, currentTokenID)
            ).to.equal(0);

            console.log(listingId);
        });
    });

    describe("Buy NFTs", () => {
        let currentTokenID;
        const listingId1 = 1;
        const listingId2 = 2;

        before(async() => {
            currentTokenID = await shProduct.currentTokenId();

            // USDC/USD aggregator
            const usdcOracle = "0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3";
            // set USDC/USD price oracle
            await priceFeed.registerOracle(mockUSDC.address, usdcOracle);
        });
        
        it("Reverts if a buyer is a seller", async() => {
            await expect(
                shMarketplace.connect(user1).buyItem(
                    listingId1,
                    mockUSDC.address,
                    user1.address
                )
            ).to.be.revertedWith("Buyer should be different from seller");
        });

        it("Reverts if an item is not buyable", async() => {
            await expect(
                shMarketplace.connect(user2).buyItem(
                    listingId1,
                    mockUSDC.address,
                    user1.address
                )
            ).to.be.revertedWith("Item not buyable");
        });

        it("Successfully buys NFT", async() => {
            // fast-forward 2 days
            await ethers.provider.send('evm_increaseTime', [2 * 24 * 3600]);
            await ethers.provider.send('evm_mine');

            await mockUSDC.mint(user2.address, parseUnits("10000", 6));

            await mockUSDC
                .connect(user2)
                .approve(shMarketplace.address, parseUnits("10000", 6));

            const unitPrice = await shMarketplace.getPrice(mockUSDC.address);
            
            let listing1 = await shMarketplace.listings(listingId1);
            
            expect(
                await shMarketplace.connect(user2).buyItem(
                    listingId1,
                    mockUSDC.address,
                    user1.address
                )
            ).to.be.emit(shMarketplace, "ItemSold").withArgs(
                user1.address, user2.address, unitPrice, listingId1
            );

            expect(
                await mockUSDC.balanceOf(user2.address)
            ).to.equal(parseUnits("7600", 6)); // 10000 - 1200 * 2 = 7600

            expect(
                await mockUSDC.balanceOf(user1.address)
            ).to.equal(parseUnits("7388", 6)); // 5000 + 1200 * 2 * 0.995 = 7388
            
            expect(
                await shNFT.balanceOf(shMarketplace.address, listing1.tokenId)
            ).to.equal(3);

            expect(
                await shNFT.balanceOf(user2.address, listing1.tokenId)
            ).to.equal(2);

            expect(
                await shNFT.balanceOf(user1.address, listing1.tokenId)
            ).to.equal(0);

            listing1 = await shMarketplace.listings(listingId1);
            
            expect(listing1.listingId).to.equal(0);
        });
    });
});
