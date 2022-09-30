const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ShFactory test suite", function () {
  let shFactory, shProduct, shNFT;
  let owner, qredoDeribit
  before(async () => {
    [owner, qredoDeribit] = await ethers.getSigners();

    const SHFactory = await ethers.getContractFactory("SHFactory");
    shFactory = await SHFactory.deploy();
    await shFactory.deployed();

    const SHNFT = await ethers.getContractFactory("SHNFT");
    shNFT = await SHNFT.deploy(
      "Superhedge NFT", "SHN", shFactory.address
    );
    await shNFT.deployed();
  });

  it("Create product", async() => {
    const productName = "BTC Defensive Spread";

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
        uri: ""
      }
    )).to.be.emit(shFactory, "ProductCreated");

    expect(await shFactory.numOfProducts()).to.equal(1);

    // get product
    const productAddr = await shFactory.getProduct(productName);
    console.log(`SHProduct contract deployed at ${productAddr}`);
    const SHProduct = await ethers.getContractFactory("SHProduct");
    shProduct = SHProduct.attach(productAddr);
  });
});
