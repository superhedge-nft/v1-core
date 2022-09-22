const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ShFactory test suite", function () {
  let shFactory, shProduct;
  let owner, qredoDeribit
  before(async () => {
    [owner, qredoDeribit] = await ethers.getSigners();

    const SHFactory = await ethers.getContractFactory("SHFactory");
    shFactory = await SHFactory.deploy(
      "Superhedge NFT",
      "SHN"
    );
    await shFactory.deployed();
  });

  it("Create product", async() => {
    const shNFT = await shFactory.shNFT();
    const productName = "BTC Defensive Spread";

    expect(await shFactory.createProduct(
      productName,
      "BTC/USD",
      qredoDeribit.address,
      10, // 0.10% in basis points
      25000,
      20000,
      1664640000,
      1666972800,
      1000000,
      shNFT
    )).to.be.emit(shFactory, "ProductCreated");

    // get product
    const productAddr = await shFactory.getProduct(productName);
    console.log(`SHProduct contract deployed at ${productAddr}`);
  });
});
