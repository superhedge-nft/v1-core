const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

const { parseEther, parseUnits } = ethers.utils;

describe("SHFactory test suite", function () {
    let shFactory, shProduct, shNFT, usdc;
    let owner, user1, user2, whaleSigner;

    const whaleAddress = "0xDa9CE944a37d218c3302F6B82a094844C6ECEb17";
    const qredoWallet = "0xebC37b9cb1657C50676526d28fFfFd54B0A06be2";
    const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";

    // Lido Locator
    const lidoLocatorAddr = "0xC1d0b3DE6792Bf6b4b37EccdcC24e45978Cfd2Eb";
    const lidoAddr = "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84";

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
            issuanceDate: Math.floor(Date.now() / 1000) + 7 * 86400,
            maturityDate: Math.floor(Date.now() / 1000) + 30 * 86400,
            apy: "7-15%",
            uri: "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH"
        }

        it("Successfully created", async () => {
            await expect(shFactory.createProduct(
              productName,
              "ETH/USDC",
              ethers.constants.AddressZero,
              owner.address,
              shNFT.address,
              qredoWallet,
              500,
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

        it("Update product name", async() => {
            await expect(
                shFactory.setProductName(productName, shProduct.address)
            ).to.be.revertedWith("Product already exists");

            const newName = "ETH Bullish Spread1";
            await expect(
                shFactory.setProductName(newName, shProduct.address)
            ).to.emit(shFactory, "ProductUpdated").withArgs(shProduct.address, newName);
            
            expect(await shProduct.name()).to.equal(newName);
        });
    });

    describe("Deposit", () => {
        before(async() => {
        });

        it("Reverts if the product status is not 'Accepted'", async () => {
            await expect(
              shProduct.connect(user1).depositETH(false, {value: parseEther("2")})
            ).to.be.revertedWith("Not accepted status");
        });

        it("Reverts if the amount is invalid", async () => {
            await shProduct.whitelist(owner.address);
            await shProduct.fundAccept();

            await expect(
                shProduct.connect(user1).depositETH(false, {value: parseEther("0")})
            ).to.be.revertedWith("Amount must be greater than zero");
    
            await expect(
                shProduct.connect(user1).depositETH(false, {value: parseUnits("1", 17)})
            ).to.be.revertedWith("Amount must be whole-number eth");
    
            await expect(
                shProduct.connect(user1).depositETH(false, {value: parseEther("1000")})
            ).to.be.revertedWith("Product is full");
        });

        it("User1 deposits 2 ETH", async () => {
            const amount = parseEther("2");
            const supply = 2;

            const currentTokenID = await shProduct.currentTokenId();
            
            await expect(
                shProduct.connect(user1).depositETH(false, { value: amount })
            ).to.be.emit(shProduct, "Deposit").withArgs(
                user1.address, amount, currentTokenID, supply
            );

            expect(
                await ethers.provider.getBalance(shProduct.address)
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
            const amount2 = parseEther("1");
            await expect(
              shProduct.connect(user2).depositETH(false, { value: amount2 })
            ).to.be.revertedWith("Not accepted status");
        });
    });

    describe("Distribute funds & check coupon balance", () => {
        it("Distribute funds", async() => {
            const optionRate = 20;
            const yieldRate = 80;

            await expect(
                shProduct.distributeFunds(yieldRate, lidoLocatorAddr)
            ).to.emit(shProduct, "DistributeFunds")
            .withArgs(qredoWallet, optionRate, lidoAddr, yieldRate);
            
            expect(await shProduct.isDistributed()).to.equal(true);
        });
        
        it("Check coupon balance", async () => {
            await expect(
                shProduct.issuance()
            ).to.emit(shProduct, "Issuance");

            await expect(
                shProduct.weeklyCoupon()
            ).to.emit(shProduct, "WeeklyCoupon");
            let user1Info = await shProduct.userInfo(user1.address);

            const currentTokenID = await shProduct.currentTokenId();
            const tokenSupply = parseInt(await shNFT.balanceOf(user1.address, currentTokenID));
            const couponBalance = tokenSupply * Math.pow(10, 18) * 10 / 10000;
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
            
            const couponBalance = currentSupply * Math.pow(10, 18) * 10 / 10000;

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
            await qredoSigner.sendTransaction({
                to: shProduct.address,
                value: parseEther("1")
            });

            await expect(
                shProduct.connect(user1).withdrawCoupon()
            ).to.emit(shProduct, "WithdrawCoupon").withArgs(user1.address, user1Info.coupon);

            await expect(
                shProduct.connect(user2).withdrawCoupon()
            ).to.emit(shProduct, "WithdrawCoupon").withArgs(user2.address, user2Info.coupon);
        });
    });

    /* describe("After maturity", () => {
        it("Token Ids change", async() => {
            const prevTokenId = await shProduct.currentTokenId();
            await expect(
                shProduct.mature()
            ).to.emit(shProduct, "Mature");

            expect(await shProduct.prevTokenId()).to.equal(prevTokenId);
        });

        it("Update issuance & maturity dates", async() => {
            const issuanceDate = Math.floor(Date.now() / 1000) + 2 * 7 * 86400;
            const maturityDate = Math.floor(Date.now() / 1000) + 6 * 7 * 86400;

            await expect(
                shProduct.updateTimes(issuanceDate, maturityDate)
            ).to.emit(shProduct, "UpdateTimes").withArgs(issuanceDate, maturityDate);
        });

        it("Redeem yield from Compound", async() => {
            await expect(
                shProduct.redeemYield(cUSDCAddr)
            ).to.emit(shProduct, "RedeemYield").withArgs(cUSDCAddr);
            expect(await shProduct.isDistributed()).to.equal(false);
        });

        it("Redeem option from qredo wallet", async() => {
            const transferAmount = await usdc.balanceOf(qredoWallet);
            
            await usdc.connect(qredoSigner).approve(shProduct.address, transferAmount);
            await expect(
                shProduct.connect(qredoSigner).redeemOptionPayout(transferAmount)
            ).to.emit(shProduct, "RedeemOptionPayout").withArgs(qredoWallet, transferAmount);

            expect(await shProduct.optionProfit()).to.equal(transferAmount);
        });
    }); */

    /* describe("Next issuance cycle", () => {
        it("Accepting funds, check option payout", async() => {
            let user1Info = await shProduct.userInfo(user1.address);
            let user2Info = await shProduct.userInfo(user2.address);
            expect(user1Info.optionPayout).to.equal(0);
            expect(user2Info.optionPayout).to.equal(0);
            const optionProfit = await shProduct.optionProfit();

            await expect(
                shProduct.fundAccept()
            ).to.emit(shProduct, "OptionPayout").withArgs(user2.address, optionProfit);

            user1Info = await shProduct.userInfo(user1.address);
            user2Info = await shProduct.userInfo(user2.address);

            expect(user1Info.optionPayout).to.equal(0);
            expect(user2Info.optionPayout).to.equal(optionProfit);
        });

        it("Withdraws their funds", async() => {
            await expect(
                shProduct.connect(user1).withdrawPrincipal()
            ).to.be.revertedWith("No principal");

            const prevTokenId = await shProduct.prevTokenId();
            const prevSupply = await shNFT.balanceOf(user2.address, prevTokenId);

            const currentTokenId = await shProduct.currentTokenId();
            const currentSupply = await shNFT.balanceOf(user2.address, currentTokenId);
            
            const principal = (currentSupply + prevSupply) * 1000 * Math.pow(10, 6);

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
        });
        
        it("Update parameters after fund is locked", async() => {
            await shProduct.fundLock();
            await shProduct.updateCoupon(10);
            await shProduct.updateStrikePrices(1300, 1500, 0, 0);
            await shProduct.updateURI("https://ipfs.filebase.io/ipfs/QmaXPe1yB864wN4jjFff645n78yzuGB2hMrNxQNvEX9f9a");
            await shProduct.updateTRs(11560, 10830);
            await shProduct.updateAPY("8-13%");
            await shProduct.updateParameters(
                10, 1300, 1500, 0, 0, 11560, 10830, "8-12%", "https://ipfs.filebase.io/ipfs/QmaXPe1yB864wN4jjFff645n78yzuGB2hMrNxQNvEX9f9a"
            );
        });

        it("new issuance", async() => {
            const prevTokenId = await shProduct.prevTokenId();
            const prevSupply = await shNFT.balanceOf(user2.address, prevTokenId);
            await shProduct.issuance();
            const currentTokenID = await shProduct.currentTokenId();
            expect(await shNFT.balanceOf(user2.address, currentTokenID)).to.equal(prevSupply);
        });

        it("remove from whitelist", async() => {
            await shProduct.removeFromWhitelist(owner.address);
            expect(await shProduct.whitelisted(owner.address)).to.equal(false);
        });
    }); */

    describe("Pausable", () => {
        it("Pause the products", async() => {
            await shProduct.pause();
            expect(await shProduct.paused()).to.equal(true);
        });

        it("Unpause the products", async() => {
            await shProduct.unpause();
            expect(await shProduct.paused()).to.equal(false);
        });
    });
});
