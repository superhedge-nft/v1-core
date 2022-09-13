const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ShProduct", function () {
  let mockUSDC, shProduct;
  before(async () => {
    const [owner, deribit, otherAccount] = await ethers.getSigners();
    const MockUSDC = await ethers.getContractFactory("MockUSDC");
    mockUSDC = await MockUSDC.deploy();
    await mockUSDC.deployed();

    const ShProduct = await ethers.getContractFactory("ShProduct");
    shProduct = await ShProduct.deploy(
      mockUSDC.address,
      deribit.address,
      "Superhedge NFT",
      "SHN"
    );
    await shProduct.deployed();

    console.log(shProduct.address);
  });

  it("Should set the right USDC address", async() => {
    expect(await shProduct.USDC()).to.equal(mockUSDC.address);
  });
});
