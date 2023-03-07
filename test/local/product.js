const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

const { parseUnits } = ethers.utils;

describe("SHFactory test suite", function () {
  let shFactory, shProduct, shNFT, mockUSDC;
  let owner, qredoWallet
  before(async () => {
    [owner, qredoWallet, user1, user2] = await ethers.getSigners();

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
      issuanceDate: 1678406400,
      maturityDate: 1681084800,
      apy: "7-15%",
      uri: "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH"
    }

    it("Reverts if max capacity is not whole-number thousands", async () => {
      await expect(
        shFactory.createProduct(
          productName,
          "ETH/USDC",
          mockUSDC.address,
          owner.address,
          shNFT.address,
          qredoWallet.address,
          2500,
          issuanceCycle
        )
      ).to.be.revertedWith("Max capacity must be whole-number thousands");
    });

    it("Successfully created", async () => {
      expect(await shFactory.createProduct(
        productName,
        "ETH/USDC",
        mockUSDC.address,
        owner.address,
        shNFT.address,
        qredoWallet.address,
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
      await mockUSDC.mint(user1.address, parseUnits("10000", 6));
      await mockUSDC.mint(user2.address, parseUnits("10000", 6));

      await shProduct.whitelist(owner.address);
    });

    it("Reverts if the product status is not 'Accepted'", async () => {
      await expect(
        shProduct.deposit(parseUnits("2000", 6), false)
      ).to.be.revertedWith("Not accepted status");
    });

    it("Reverts if the amount is invalid", async () => {
      await shProduct.fundAccept();

      await expect(
        shProduct.deposit(parseUnits("0", 6), false)
      ).to.be.revertedWith("Amount must be greater than zero");

      await expect(
        shProduct.deposit(parseUnits("1500", 6), false)
      ).to.be.revertedWith("Amount must be whole-number thousands");

      await expect(
        shProduct.deposit(parseUnits("20000000", 6), false)
      ).to.be.revertedWith("Product is full");
    });

    it("User1 deposits 2000 USDC", async () => {
      const amount = parseUnits("2000", 6);
      const supply = 2000 / 1000;
      await mockUSDC.connect(user1).approve(shProduct.address, amount);

      const currentTokenID = await shProduct.currentTokenId();
      
      expect(
        await shProduct.connect(user1).deposit(amount, false)
      ).to.be.emit(shProduct, "Deposit").withArgs(user1.address, amount, currentTokenID, supply);

      expect(
        await mockUSDC.balanceOf(shProduct.address)
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
    });

    it("User2 deposits 1000 USDC but it is reverted since fund is locked", async () => {
      await shProduct.fundLock();
      const amount2 = parseUnits("1000", 6);
      await expect(
        shProduct.connect(user2).deposit(amount2, false)
      ).to.be.revertedWith("Not accepted status");
    });
  });

  describe("Check coupon & option payout balance", () => {
    before(async() => {
      await shProduct.issuance();
    });

    it("Check coupon balance after one week", async () => {
      await shProduct.weeklyCoupon();
      const currentTokenID = await shProduct.currentTokenId();
      const tokenSupply = parseInt(await shNFT.balanceOf(user1.address, currentTokenID));
      const couponBalance = tokenSupply * 1000 * Math.pow(10, 6) * 10 / 10000;
      expect(await shProduct.couponBalance(user1.address)).to.equal(couponBalance);
    });

    it("Check coupon balance after transfer NFT into user2 wallet", async () => {
      const currentTokenID = await shProduct.currentTokenId();
      const tokenSupply = await shNFT.balanceOf(user1.address, currentTokenID);

      await shNFT.connect(user1).safeTransferFrom(
        user1.address,
        user2.address,
        currentTokenID,
        tokenSupply,
        []
      );
      
      const prevUser1Coupon = parseInt(await shProduct.couponBalance(user1.address));
      const prevUser2Coupon = parseInt(await shProduct.couponBalance(user2.address));
      await shProduct.weeklyCoupon();
      const user1Supply = parseInt(await shNFT.balanceOf(user1.address, currentTokenID));
      const user1Coupon = user1Supply * 1000 * Math.pow(10, 6) * 10 / 10000;
      expect(await shProduct.couponBalance(user1.address)).to.equal(prevUser1Coupon + user1Coupon);
      
      const user2Supply = parseInt(await shNFT.balanceOf(user2.address, currentTokenID));
      const user2Coupon = user2Supply * 1000 * Math.pow(10, 6) * 10 / 10000;
      expect(await shProduct.couponBalance(user2.address)).to.equal(prevUser2Coupon + user2Coupon);
    });
  });
});
