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
        const productName = "ETH Bullish Spread";
        const issuanceCycle = {
            coupon: 10,
            strikePrice1: 1400,
            strikePrice2: 1600,
            strikePrice3: 0,
            strikePrice4: 0,
            tr1: 11750,
            tr2: 10040,
            issuanceDate: 1677600000,
            maturityDate: 1680019200,
            apy: "7-15%",
            uri: "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH"
        }

        it("Reverts if max capacity is not whole-number thousands", async () => {
            await expect(
              shFactory.createProduct(
                productName,
                "ETH/USDC",
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
              "ETH/USDC",
              usdc.address,
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
        
            expect(await shProduct.currentTokenId()).to.equal(1);
            expect(await shProduct.shNFT()).to.equal(shNFT.address);
        });
    });

    describe("Deposit", () => {
        before(async() => {
            await usdc.connect(whaleSigner).transfer(user1.address, parseUnits("10000", 6));
            await usdc.connect(whaleSigner).transfer(user2.address, parseUnits("10000", 6));
            // await usdc.connect(whaleSigner).transfer(qredoWallet, parseUnits("10000", 6));
        });

        it("Reverts if the product status is not 'Accepted'", async () => {
            await expect(
              shProduct.connect(user1).deposit(parseUnits("2000", 6), false)
            ).to.be.revertedWith("Not accepted status");
        });

        it("Reverts if the amount is invalid", async () => {
            await shProduct.whitelist(owner.address);
            await shProduct.fundAccept();

            await expect(
                shProduct.connect(user1).deposit(parseUnits("0", 6), false)
            ).to.be.revertedWith("Amount must be greater than zero");
    
            await expect(
                shProduct.connect(user1).deposit(parseUnits("1500", 6), false)
            ).to.be.revertedWith("Amount must be whole-number thousands");
    
            await expect(
                shProduct.connect(user1).deposit(parseUnits("20000000", 6), false)
            ).to.be.revertedWith("Product is full");
        });

        it("User1 deposits 2000 USDC", async () => {
            const amount = parseUnits("2000", 6);
            const supply = 2000 / 1000;
            await usdc.connect(user1).approve(shProduct.address, amount);

            const currentTokenID = await shProduct.currentTokenId();
            
            expect(
                await shProduct.connect(user1).deposit(amount, false)
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
        });

        it("set token URI", async () => {
            const tokenId = await shProduct.currentTokenId();
            const URI = "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH";
            await shNFT.setTokenURI(tokenId, URI);
            console.log(tokenId);
            // Update URI during fund lock
            await shProduct.fundLock();
            expect(
                await shProduct.updateURI(URI)
            ).to.emit(shProduct, "UpdateURI").withArgs(tokenId, URI);
        });

        it("User2 deposits 1000 USDC but it is reverted since fund is locked", async () => {
            const amount2 = parseUnits("1000", 6);
            await expect(
              shProduct.connect(user2).deposit(amount2, false)
            ).to.be.revertedWith("Not accepted status");
        });
    });

    describe("Distribute assets & check coupon balance", () => {
        it("Distribute with Compound", async() => {
            const optionRate = 20;
            const yieldRate = 80;

            expect(
                await shProduct.distributeWithComp(yieldRate, cUSDCAddr)
            ).to.emit(shProduct, "DistributeWithComp")
            .withArgs(qredoWallet, optionRate, cUSDCAddr, yieldRate);
            
            expect(await shProduct.isDistributed()).to.equal(true);
        });
        
        it("Check coupon balance", async () => {
            expect(
                await shProduct.issuance()
            ).to.emit(shProduct, "Issuance");

            expect(
                await shProduct.weeklyCoupon()
            ).to.emit(shProduct, "WeeklyCoupon");
            let user1Info = await shProduct.userInfo(user1.address);

            const currentTokenID = await shProduct.currentTokenId();
            const tokenSupply = parseInt(await shNFT.balanceOf(user1.address, currentTokenID));
            const couponBalance = tokenSupply * 1000 * Math.pow(10, 6) * 10 / 10000;
            expect(user1Info.coupon).to.equal(couponBalance);
        });

        it("check coupon balance after NFT transfer", async () => {
            const currentTokenID = await shProduct.currentTokenId();
            const currentSupply = await shNFT.balanceOf(user1.address, currentTokenID);
            
            await shNFT.connect(user1).safeTransferFrom(
                user1.address,
                user2.address,
                currentTokenID,
                currentSupply,
                []
            );

            expect(
                await shProduct.weeklyCoupon()
            ).to.emit(shProduct, "WeeklyCoupon");
            
            const couponBalance = currentSupply * 1000 * Math.pow(10, 6) * 10 / 10000;

            let user1Info = await shProduct.userInfo(user1.address);
            let user2Info = await shProduct.userInfo(user2.address);

            expect(user1Info.coupon).to.equal(couponBalance);
            expect(user2Info.coupon).to.equal(couponBalance);

            expect(
                await shProduct.weeklyCoupon()
            ).to.emit(shProduct, "WeeklyCoupon");

            user1Info = await shProduct.userInfo(user1.address);
            user2Info = await shProduct.userInfo(user2.address);

            expect(user1Info.coupon).to.equal(couponBalance);
            expect(user2Info.coupon).to.equal(couponBalance * 2);
        });

        it("Withdraws coupon", async() => {
            await expect(
                shProduct.connect(user1).withdrawCoupon()
            ).to.be.revertedWith("Insufficient balance");
            
            const user1Info = await shProduct.userInfo(user1.address);
            const user2Info = await shProduct.userInfo(user2.address);

            // Pre fund from Qredo wallet
            await usdc.connect(user1).transfer(
                shProduct.address, parseUnits("100", 6)
            );

            expect(
                await shProduct.connect(user1).withdrawCoupon()
            ).to.emit(shProduct, "WithdrawCoupon").withArgs(user1.address, user1Info.coupon);

            /* expect(
                await shProduct.connect(user2).withdrawCoupon()
            ).to.emit(shProduct, "WithdrawCoupon").withArgs(user2.address, user2Info.coupon); */
        });
    });

    describe("After maturity", () => {
        it("Token Ids change", async() => {
            const prevTokenId = await shProduct.currentTokenId();
            expect(
                await shProduct.mature()
            ).to.emit(shProduct, "Mature");

            expect(await shProduct.prevTokenId()).to.equal(prevTokenId);
        });

        it("Update issuance & maturity dates", async() => {
            const issuanceDate = 1677600000;
            const maturityDate = 1680019200;

            expect(
                await shProduct.updateTimes(issuanceDate, maturityDate)
            ).to.emit(shProduct, "UpdateTimes").withArgs(issuanceDate, maturityDate);
        });

        it("Redeem yield from Compound", async() => {
            expect(
                await shProduct.redeemYieldFromComp(cUSDCAddr)
            ).to.emit(shProduct, "RedeemYieldFromComp").withArgs(cUSDCAddr);
            expect(await shProduct.isDistributed()).to.equal(false);
        });

        it("Redeem option from qredo wallet", async() => {
            const transferAmount = await usdc.balanceOf(qredoWallet);
            console.log("option profit: ", transferAmount);
            await usdc.connect(qredoSigner).approve(shProduct.address, transferAmount);
            expect(
                await shProduct.connect(qredoSigner).redeemOptionPayout(transferAmount)
            ).to.emit(shProduct, "RedeemOptionPayout").withArgs(qredoWallet, transferAmount);

            expect(await shProduct.optionProfit()).to.equal(transferAmount);
        });
    });

    describe("Next issuance cycle", () => {
        it("Accepting funds, check option payout", async() => {
            let user1Info = await shProduct.userInfo(user1.address);
            let user2Info = await shProduct.userInfo(user2.address);
            expect(user1Info.optionPayout).to.equal(0);
            expect(user2Info.optionPayout).to.equal(0);
            const optionProfit = await shProduct.optionProfit();

            await shProduct.fundAccept();

            user1Info = await shProduct.userInfo(user1.address);
            user2Info = await shProduct.userInfo(user2.address);

            expect(user1Info.optionPayout).to.equal(0);
            expect(user2Info.optionPayout).to.equal(optionProfit);
            // Top-up on
            /* await usdc.connect(user2).approve(shProduct.address, parseUnits("596", 6));
            await shProduct.connect(user2).deposit(parseUnits("596", 6), true);
            user2Info = await shProduct.userInfo(user2.address);
            console.log(user2Info.coupon);
            console.log(user2Info.optionPayout); */
        });

        /* it("Withdraws their funds", async() => {
            await expect(
                shProduct.connect(user1).withdrawPrincipal()
            ).to.be.revertedWith("No principal");

            console.log(await usdc.balanceOf(user2.address));
            const prevTokenId = await shProduct.prevTokenId();
            const prevSupply = await shNFT.balanceOf(user2.address, prevTokenId);

            const currentTokenId = await shProduct.currentTokenId();
            const currentSupply = await shNFT.balanceOf(user2.address, currentTokenId);

            expect(
                await shProduct.connect(user2).withdrawPrincipal()
            ).to.emit(shProduct, "WithdrawPrincipal").withArgs(
                user2.address,
                prevTokenId,
                prevSupply,
                currentTokenId,
                currentSupply
            );

            console.log(await usdc.balanceOf(user2.address));
        }); */
        
        it("Update parameters after fund is locked", async() => {
            await shProduct.fundLock();
            await shProduct.updateCoupon(20);
            await shProduct.updateStrikePrices(1300, 1500, 0, 0);
            await shProduct.updateURI("https://ipfs.filebase.io/ipfs/QmaXPe1yB864wN4jjFff645n78yzuGB2hMrNxQNvEX9f9a");
            await shProduct.updateTRs(11560, 10830);
            await shProduct.updateAPY("8-13%");
            await shProduct.updateParameters(
                20, 1300, 1500, 0, 0, 11560, 10830, "8-12%", "https://ipfs.filebase.io/ipfs/QmaXPe1yB864wN4jjFff645n78yzuGB2hMrNxQNvEX9f9a"
            );
        });

        it("new issuance", async() => {
            const prevTokenId = await shProduct.prevTokenId();
            const prevSupply = await shNFT.balanceOf(user2.address, prevTokenId);
            await shProduct.issuance();
            const currentTokenID = await shProduct.currentTokenId();
            expect(await shNFT.balanceOf(user2.address, currentTokenID)).to.equal(prevSupply);
        });
    });

    describe("Pausable", () => {
        const productName = "ETH Bullish Spread";
        const issuanceCycle = {
            coupon: 10,
            strikePrice1: 24000,
            strikePrice2: 22000,
            strikePrice3: 0,
            strikePrice4: 0,
            tr1: 11750,
            tr2: 10040,
            issuanceDate: 1677600000,
            maturityDate: 1680019200,
            apy: "7-15%",
            uri: "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH"
        }

        it("Pause the products", async() => {
            await shProduct.pause();
            expect(await shProduct.paused()).to.equal(true);

            expect(await shFactory.createProduct(
                productName,
                "ETH/USDC",
                usdc.address,
                owner.address,
                shNFT.address,
                qredoWallet,
                10000,
                issuanceCycle
            )).to.be.emit(shFactory, "ProductCreated");
        });

        it("Unpause the products", async() => {
            await shProduct.unpause();
            expect(await shProduct.paused()).to.equal(false);

            await expect(shFactory.createProduct(
                productName,
                "ETH/USDC",
                usdc.address,
                owner.address,
                shNFT.address,
                qredoWallet,
                10000,
                issuanceCycle
            )).to.be.revertedWith("Product already exists");
        });
    });
});
