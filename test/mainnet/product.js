const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

const { parseEther, parseUnits } = ethers.utils;

describe("SHFactory test suite", function () {
    let shFactory, shProduct, shNFT, usdc;
    let aurosPool; // Clearpool contracts
    let cUSDC; // Compound cUSDC contract
    let owner, user1, user2, whaleSigner;

    const whaleAddress = "0xDa9CE944a37d218c3302F6B82a094844C6ECEb17";
    const qredoWallet = "0xebC37b9cb1657C50676526d28fFfFd54B0A06be2";
    const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";

    // Clearpools
    const aurosPoolAddr = "0x3aeB3a8F0851249682A6a836525CDEeE5aA2A153";
    const cUSDCAddr = "0x39AA39c021dfbaE8faC545936693aC917d5E7563";

    before(async () => {
        [owner, user1, user2] = await ethers.getSigners();
    
        const SHFactory = await ethers.getContractFactory("SHFactory");
        shFactory = await upgrades.deployProxy(SHFactory, []);
        await shFactory.deployed();
    
        const SHNFT = await ethers.getContractFactory("SHNFT");
        shNFT = await upgrades.deployProxy(SHNFT, [
          "Superhedge NFT", "SHN", shFactory.address
        ]);
        await shNFT.deployed();
    
        usdc = await ethers.getContractAt("IERC20", USDC);

        console.log(usdc.address);

        aurosPool = await ethers.getContractAt(
            "IPoolMaster",
            aurosPoolAddr
        );
        
        cUSDC = await ethers.getContractAt(
            "ICErc20",
            cUSDCAddr
        );

        // unlock accounts
        await network.provider.send("hardhat_impersonateAccount", [whaleAddress]);
        await network.provider.send("hardhat_impersonateAccount", [qredoWallet]);

        // send enough ETH
        await owner.sendTransaction({
            to: whaleAddress,
            value: parseEther("5")
        });

        await owner.sendTransaction({
            to: qredoWallet,
            value: parseEther("2")
        });

        whaleSigner = ethers.provider.getSigner(whaleAddress);
        qredoSigner = ethers.provider.getSigner(qredoWallet);
    });

    describe("Create product", () => {
        const productName = "BTC Defensive Spread";
        const issuanceCycle = {
            coupon: 10,
            strikePrice1: 25000,
            strikePrice2: 20000,
            strikePrice3: 0,
            strikePrice4: 0,
            uri: "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH"
        }

        it("Reverts if max capacity is not whole-number thousands", async () => {
            await expect(
              shFactory.createProduct(
                productName,
                "BTC/USD",
                usdc.address,
                owner.address,
                shNFT.address,
                qredoWallet,
                2500,
                issuanceCycle
              )
            ).to.be.revertedWith("Max capacity must be whole-number thousands");
        });

        it("Successfully created", async () => {
            expect(await shFactory.createProduct(
              productName,
              "BTC/USD",
              usdc.address,
              owner.address,
              shNFT.address,
              qredoWallet,
              1000000,
              issuanceCycle
            )).to.be.emit(shFactory, "ProductCreated");
        
            expect(await shFactory.numOfProducts()).to.equal(1);
        
            // get product
            const productAddr = await shFactory.getProduct(productName);
            const SHProduct = await ethers.getContractFactory("SHProduct");
            shProduct = SHProduct.attach(productAddr);
        
            expect(await shProduct.currentTokenId()).to.equal(0);
            expect(await shProduct.shNFT()).to.equal(shNFT.address);
        });
    });

    describe("Deposit", () => {
        before(async() => {
            await usdc.connect(whaleSigner).transfer(user1.address, parseUnits("10000", 6));
            await usdc.connect(whaleSigner).transfer(user2.address, parseUnits("10000", 6));
        });

        it("Reverts if the product status is not 'Accepted'", async () => {
            await expect(
              shProduct.connect(user1).deposit(parseUnits("2000", 6))
            ).to.be.revertedWith("Not accepted status");
        });

        it("Reverts if the amount is invalid", async () => {
            await shProduct.whitelist(owner.address);
            await shProduct.fundAccept();

            await expect(
                shProduct.connect(user1).deposit(parseUnits("0", 6))
            ).to.be.revertedWith("Amount must be greater than zero");
    
            await expect(
                shProduct.connect(user1).deposit(parseUnits("1500", 6))
            ).to.be.revertedWith("Amount must be whole-number thousands");
    
            await expect(
                shProduct.connect(user1).deposit(parseUnits("20000000", 6))
            ).to.be.revertedWith("Product is full");
        });

        it("User1 deposits 2000 USDC", async () => {
            const amount = parseUnits("2000", 6);
            const supply = 2000 / 1000;
            await usdc.connect(user1).approve(shProduct.address, amount);

            const currentTokenID = await shProduct.currentTokenId();
            
            expect(
                await shProduct.connect(user1).deposit(amount)
            ).to.be.emit(shProduct, "Deposit").withArgs(
                user1.address, amount, currentTokenID, supply
            );

            expect(
                await usdc.balanceOf(shProduct.address)
            ).to.equal(amount);

            expect(
                await shNFT.balanceOf(user1.address, currentTokenID)
            ).to.equal(2);

            expect(await shProduct.currentCapacity()).to.equal(amount);
            expect(await shProduct.numOfInvestors()).to.equal(1);
        });

        it("set token URI", async () => {
            const tokenId = await shProduct.currentTokenId();
            const URI = "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH";
            await shNFT.setTokenURI(tokenId, URI);
        });

        it("User2 deposits 1000 USDC but it is reverted since fund is locked", async () => {
            await shProduct.fundLock();
            const amount2 = parseUnits("1000", 6);
            await expect(
              shProduct.connect(user2).deposit(amount2)
            ).to.be.revertedWith("Not accepted status");
        });
    });

    describe("Check coupon & option payout balance, distribute asset", () => {
        before(async() => {
            await shProduct.issuance();
        });
      
        it("Check coupon balance after one week", async () => {
            await shProduct.weeklyCoupon();
            const userInfo = await shProduct.userInfo(user1.address);
            console.log(userInfo);
            const currentTokenID = await shProduct.currentTokenId();
            const tokenSupply = parseInt(await shNFT.balanceOf(user1.address, currentTokenID));
            const couponBalance = tokenSupply * 1000 * Math.pow(10, 6) * 10 / 10000;
            expect(userInfo.coupon).to.equal(couponBalance);
            console.log(await ethers.provider.getBalance(owner.address));
        });

        /* it("Distribute with Clearpool", async () => {
            const optionRate = 20;
            const yieldRates = [80];
            const clearpools = [aurosPoolAddr];
            expect(
                await shProduct.distributeWithClear(yieldRates, clearpools)
            ).to.emit(shProduct, "DistributeWithClear")
            .withArgs(qredoWallet, optionRate, clearpools, yieldRates)

            console.log(await aurosPool.balanceOf(shProduct.address));
            console.log(await aurosPool.symbol());

            console.log(await usdc.balanceOf(qredoWallet));
            expect(await shProduct.isDistributed()).to.equal(true);
        }); */

        it("Distribute with Compound", async() => {
            const optionRate = 20;
            const yieldRate = 80;

            expect(
                await shProduct.distributeWithComp(yieldRate, cUSDCAddr)
            ).to.emit(shProduct, "DistributeWithComp")
            .withArgs(qredoWallet, optionRate, cUSDCAddr, yieldRate);
            
            console.log(await cUSDC.balanceOf(shProduct.address));
            console.log(await usdc.balanceOf(qredoWallet));
            expect(await shProduct.isDistributed()).to.equal(true);
        });
    });

    describe("Redeem prinicipal & interest, option", () => {
        before(async() => {
            await shProduct.mature();
        });

        it("Redeem option from qredo wallet", async() => {
            const transferAmount = await usdc.balanceOf(qredoWallet);
            await usdc.connect(qredoSigner).approve(shProduct.address, transferAmount);
            expect(
                await shProduct.connect(qredoSigner).redeemOptionPayout(transferAmount)
            ).to.emit(shProduct, "RedeemOptionPayout").withArgs(qredoWallet, transferAmount);
        });

        /* it("Redeem yield from Clearpool", async() => {
            const clearpools = [aurosPoolAddr];

            expect(
                await shProduct.redeemYieldFromClear(clearpools)
            ).to.emit(shProduct, "RedeemYieldFromClear");
        }); */

        it("Redeem yield from Compound", async() => {
            expect(
                await shProduct.redeemYieldFromComp(cUSDCAddr)
            ).to.emit(shProduct, "RedeemYieldFromComp").withArgs(cUSDCAddr);
            expect(await shProduct.isDistributed()).to.equal(false);
        });
    });

    describe("Pausable", () => {
        const productName = "BTC Defensive Spread";
        const issuanceCycle = {
            coupon: 10,
            strikePrice1: 25000,
            strikePrice2: 20000,
            strikePrice3: 0,
            strikePrice4: 0,
            uri: "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH"
        };

        it("Pause the products", async() => {
            await shProduct.pause();
            expect(await shProduct.paused()).to.equal(true);

            expect(await shFactory.createProduct(
                productName,
                "BTC/USD",
                usdc.address,
                owner.address,
                shNFT.address,
                qredoWallet,
                1000000,
                issuanceCycle
            )).to.be.emit(shFactory, "ProductCreated");
        });

        it("Unpause the products", async() => {
            await shProduct.unpause();
            expect(await shProduct.paused()).to.equal(false);

            await expect(shFactory.createProduct(
                productName,
                "BTC/USD",
                usdc.address,
                owner.address,
                shNFT.address,
                qredoWallet,
                1000000,
                issuanceCycle
            )).to.be.revertedWith("Product already exists");
        });
    });
});
