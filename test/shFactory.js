const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ShFactory test suite", function () {
  let shFactory, shProduct, shNFT;
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
    const shNFTAddr = await shFactory.shNFT();
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
      shNFTAddr
    )).to.be.emit(shFactory, "ProductCreated");

    expect(await shFactory.numOfProducts()).to.equal(1);

    // get product
    const productAddr = await shFactory.getProduct(productName);
    console.log(`SHProduct contract deployed at ${productAddr}`);
    const SHProduct = await ethers.getContractFactory("SHProduct");
    shProduct = SHProduct.attach(productAddr);
    
    const SHNFT = await ethers.getContractFactory("SHNFT");
    shNFT = SHNFT.attach(shNFTAddr);
    expect(await shProduct.tokenId()).to.equal(await shNFT.getCurrentTokenID());
  });
});
