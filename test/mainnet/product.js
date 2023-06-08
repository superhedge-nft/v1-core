const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

const { parseEther, parseUnits } = ethers.utils;

describe("SHFactory test suite", function () {
    let shFactory, shProduct, shNFT, usdc;
    let aaveLPool; // Aave v3 lending contract
    let owner, user1, user2, whaleSigner;

    const whaleAddress = "0x62383739D68Dd0F844103Db8dFb05a7EdED5BBE6";
    const qredoWallet = "0xbba1088BD130AF05AA0ab3EA89464F10C83B984A";
    const USDC = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8"; // Moonbeam Wormhole USDC

    // Aave lending pool address
    const aaveLPoolAddr = "0x794a61358D6845594F94dc1DB02A252b5b4814aD";

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
        
        aaveLPool = await ethers.getContractAt(
            "IPool",
            aaveLPoolAddr
        );

        // unlock accounts
        await network.provider.send("hardhat_impersonateAccount", [whaleAddress]);
        await network.provider.send("hardhat_impersonateAccount", [qredoWallet]);

        // send enough GLMR
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
            issuanceDate: Math.floor(Date.now() / 1000) + 7 * 86400,
            maturityDate: Math.floor(Date.now() / 1000) + 30 * 86400,
            apy: "8-13%",
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
            await expect(shFactory.createProduct(
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
            
            await expect(
                shProduct.connect(user1).deposit(amount, false)
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

            // Update URI during fund lock
            await shProduct.fundLock();

            await expect(
                shProduct.updateURI(URI)
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
        it("Distribute with Aave V3", async() => {
            const optionRate = 20;
            const yieldRate = 80;

            await expect(
                shProduct.distributeFunds(yieldRate, aaveLPoolAddr)
            ).to.emit(shProduct, "DistributeFunds")
            .withArgs(qredoWallet, optionRate, aaveLPoolAddr, yieldRate);
            
            expect(await shProduct.isDistributed()).to.equal(true);

            console.log(await usdc.balanceOf(shProduct.address));
        });
        
        it("Check coupon balance", async () => {
            await expect(
                shProduct.issuance()
            ).to.emit(shProduct, "Issuance");
            
            const currentTokenID = await shProduct.currentTokenId();
            const tokenSupply = parseInt(await shNFT.balanceOf(user1.address, currentTokenID));
            const couponBalance = tokenSupply * 1000 * Math.pow(10, 6) * 10 / 10000;

            await expect(
                shProduct.weeklyCoupon()
            ).to.emit(shProduct, "WeeklyCoupon")
            .withArgs(user1.address, couponBalance, currentTokenID, tokenSupply);

            let user1Info = await shProduct.userInfo(user1.address);

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

            await expect(
                shProduct.weeklyCoupon()
            ).to.emit(shProduct, "WeeklyCoupon");
            
            const couponBalance = currentSupply * 1000 * Math.pow(10, 6) * 10 / 10000;

            let user1Info = await shProduct.userInfo(user1.address);
            let user2Info = await shProduct.userInfo(user2.address);

            expect(user1Info.coupon).to.equal(couponBalance);
            expect(user2Info.coupon).to.equal(couponBalance);

            await expect(
                shProduct.weeklyCoupon()
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

            await expect(
                shProduct.connect(user1).withdrawCoupon()
            ).to.emit(shProduct, "WithdrawCoupon").withArgs(user1.address, user1Info.coupon);

            await expect(
                shProduct.connect(user2).withdrawCoupon()
            ).to.emit(shProduct, "WithdrawCoupon").withArgs(user2.address, user2Info.coupon);
        });
    });

    describe("After maturity", () => {
        it("Token Ids change", async() => {
            const prevTokenId = await shProduct.currentTokenId();
            await expect(
                shProduct.mature()
            ).to.emit(shProduct, "Mature");

            expect(await shProduct.prevTokenId()).to.equal(prevTokenId);
        });

        it("Update issuance & maturity dates", async() => {
            const issuanceDate = Math.floor(Date.now() / 1000) + 7 * 86400;
            const maturityDate = Math.floor(Date.now() / 1000) + 30 * 86400;

            await expect(
                shProduct.updateTimes(issuanceDate, maturityDate)
            ).to.emit(shProduct, "UpdateTimes").withArgs(issuanceDate, maturityDate);
        });

        it("Redeem yield from Moonwell", async() => {
            await expect(
                shProduct.redeemYield(aaveLPoolAddr)
            ).to.emit(shProduct, "RedeemYield");

            expect(await shProduct.isDistributed()).to.equal(false);
        });

        it("Redeem option from qredo wallet", async() => {
            const transferAmount = await usdc.balanceOf(qredoWallet);
            console.log("option profit: ", transferAmount);
            await usdc.connect(qredoSigner).approve(shProduct.address, transferAmount);
            await expect(
                shProduct.connect(qredoSigner).redeemOptionPayout(transferAmount)
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

        it("Withdraws their funds", async() => {
            await expect(
                shProduct.connect(user1).withdrawPrincipal()
            ).to.be.revertedWith("No principal");

            console.log(await usdc.balanceOf(user2.address));
            const prevTokenId = await shProduct.prevTokenId();
            const prevSupply = await shNFT.balanceOf(user2.address, prevTokenId);

            const currentTokenId = await shProduct.currentTokenId();
            const currentSupply = await shNFT.balanceOf(user2.address, currentTokenId);
            
            const principal = (parseInt(currentSupply) + parseInt(prevSupply)) * 1000 * Math.pow(10, 6);

            await expect(
                shProduct.connect(user2).withdrawPrincipal()
            ).to.emit(shProduct, "WithdrawPrincipal").withArgs(
                user2.address,
                principal,
                prevTokenId,
                prevSupply,
                currentTokenId,
                currentSupply
            );

            console.log(await usdc.balanceOf(user2.address));
        });
        
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
        it("Pause the products", async() => {
            await expect(shProduct.pause()).to.emit(shProduct, "Paused");
            expect(await shProduct.paused()).to.equal(true);
        });

        it("Unpause the products", async() => {
            await expect(shProduct.unpause()).to.emit(shProduct, "Unpaused");
            expect(await shProduct.paused()).to.equal(false);
        });
    });
});
