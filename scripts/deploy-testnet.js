// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { ethers, upgrades } = require("hardhat");

async function main() {
  // Deploy factory contract
  const SHFactory = await ethers.getContractFactory("SHFactory");
  const shFactory = await upgrades.deployProxy(SHFactory, []);
  await shFactory.deployed();

  console.log(`SHFactory deployed at ${shFactory.address}`);

  // Deploy NFT contract
  const SHNFT = await ethers.getContractFactory("SHNFT");
  const shNFT = await upgrades.deployProxy(SHNFT, [
    "Superhedge NFT", "SHN", shFactory.address
  ]);
  await shNFT.deployed();

  console.log(`SHNFT deployed at ${shNFT.address}`);

  // Create new product
  const deployer = "0x488177c42bD58104618cA771A674Ba7e4D5A2FBB";

  const issuanceCycle = {
      coupon: 10,
      strikePrice1: 25000,
      strikePrice2: 20000,
      strikePrice3: 0,
      strikePrice4: 0,
      uri: "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH"
  }

  const tx = await shFactory.createProduct(
    "BTC Defensive Spread", // product name
    "BTC/USD", // underlying
    deployer, // QREDO Wallet
    shNFT.address, // ERC1155 NFT address
    1000000, // Max capacity
    issuanceCycle // First issuance cycle
  );
  
  await tx.wait();
  
  const productAddr = await shFactory.getProduct("BTC Defensive Spread");

  console.log(`SHProduct deployed at ${productAddr}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
