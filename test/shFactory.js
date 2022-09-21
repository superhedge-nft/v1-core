const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ShFactory test suite", function () {
  let shFactory, shProduct;
  let owner, qredoDeribit
  before(async () => {
    [owner, qredoDeribit] = await ethers.getSigners();

    const ShFactory = await ethers.getContractFactory("ShFactory");
    shFactory = await ShFactory.deploy(
      "Superhedge NFT",
      "SHN"
    );
    await shFactory.deployed();

    console.log(shFactory.address);
  });

  it("Create product", async() => {
    const shNFT = await shFactory.shNFT();
    console.log(shNFT);
    await shFactory.createProduct(
      "BTC Defensive Spread",
      "BTC/USD",
      qredoDeribit.address,
      10, // 0.10% in basis points
      25000,
      20000,
      1664640000,
      1666972800,
      1000000,
      shNFT
    );
  });
});
