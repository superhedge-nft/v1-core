const { expect } = require("chai");
const { ethers } = require("hardhat");

const { parseUnits } = ethers.utils;

describe("SHFactory test suite", function () {
  let shFactory, shProduct, shNFT, mockUSDC;
  let owner, qredoDeribit
  before(async () => {
    [owner, qredoDeribit, user1, user2, mockOps] = await ethers.getSigners();

    const MockFactory = await ethers.getContractFactory("MockFactory");
    shFactory = await MockFactory.deploy();
    await shFactory.deployed();

    const SHNFT = await ethers.getContractFactory("SHNFT");
    shNFT = await SHNFT.deploy(
      "Superhedge NFT", "SHN", shFactory.address
    );
    await shNFT.deployed();

    const MockUSDC = await ethers.getContractFactory("MockUSDC");
    mockUSDC = await MockUSDC.deploy();
    await mockUSDC.deployed();
  });

  describe("Create product", () => {
    const productName = "BTC Defensive Spread";
    it("Reverts if max capacity is not whole-number thousands", async () => {
      await expect(
        shFactory.createProduct(
          productName,
          "BTC/USD",
          qredoDeribit.address,
          shNFT.address,
          2500,
          {
            coupon: 10,
            strikePrice1: 25000,
            strikePrice2: 20000,
            uri: "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH",
            issuanceDate: 0,
            maturityDate: 0
          }
        )
      ).to.be.revertedWith("Max capacity must be whole-number thousands");
    });

    it("Successfully created", async () => {
      expect(await shFactory.createProduct(
        productName,
        "BTC/USD",
        qredoDeribit.address,
        shNFT.address,
        1000000,
        {
          coupon: 10, // 0.10% in basis points
          strikePrice1: 25000,
          strikePrice2: 20000,
          uri: "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH",
          issuanceDate: 0,
          maturityDate: 0
        }
      )).to.be.emit(shFactory, "ProductCreated");
  
      expect(await shFactory.numOfProducts()).to.equal(1);
  
      // get product
      const productAddr = await shFactory.getProduct(productName);
      console.log(`SHProduct contract deployed at ${productAddr}`);
      const MockProduct = await ethers.getContractFactory("MockProduct");
      shProduct = MockProduct.attach(productAddr);
  
      expect(await shProduct.currentTokenId()).to.equal(1);
      expect(await shProduct.shNFT()).to.equal(shNFT.address);
    });
  });

  describe("Deposit", () => {
    before(async() => {
      await mockUSDC.mint(user1.address, parseUnits("10000", 6));
      await mockUSDC.mint(user2.address, parseUnits("10000", 6));

      await shProduct.setMockOps(mockOps.address);
      await shProduct.setMockUSDC(mockUSDC.address);
    });

    it("Reverts if the product status is not 'Accepted'", async () => {
      await expect(
        shProduct.deposit(parseUnits("2000", 6))
      ).to.be.revertedWith("Not accepted status");
    });

    it("Reverts if the amount is invalid", async () => {
      await shProduct.connect(mockOps).fundAccept();

      await expect(
        shProduct.deposit(parseUnits("0", 6))
      ).to.be.revertedWith("Amount must be greater than zero");

      await expect(
        shProduct.deposit(parseUnits("1500", 6))
      ).to.be.revertedWith("Amount must be whole-number thousands");

      await expect(
        shProduct.deposit(parseUnits("20000000", 6))
      ).to.be.revertedWith("Product is full");
    });

    it("User1 deposits 2000 USDC", async () => {
      const amount = parseUnits("2000", 6);
      const supply = 2000 / 1000;
      await mockUSDC.connect(user1).approve(shProduct.address, amount);

      expect(
        await shProduct.connect(user1).deposit(amount)
      ).to.be.emit(shProduct, "Deposit").withArgs(user1.address, amount, 1, supply);

      expect(
        await mockUSDC.balanceOf(shProduct.address)
      ).to.equal(amount);

      const currentTokenID = await shProduct.currentTokenId();
      expect(
        await shNFT.balanceOf(user1.address, currentTokenID)
      ).to.equal(2);

      expect(await shProduct.currentCapacity()).to.equal(amount);
    });

    it("Lock funds", async () => {
      await shProduct.connect(mockOps).fundLock();
    });

    it("User2 deposits 1000 USDC but it is reverted since fund is locked", async () => {
      const amount2 = parseUnits("1000", 6);
      await expect(
        shProduct.connect(user2).deposit(amount2)
      ).to.be.revertedWith("Not accepted status");
    });
  });
});
