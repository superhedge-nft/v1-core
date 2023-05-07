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

  // Deploy MockUSDC contract
  const MockUSDC = await ethers.getContractFactory("MockUSDC");
  const mockUSDC = await MockUSDC.deploy();
  await mockUSDC.deployed();

  console.log(`MockUSDC deployed at ${mockUSDC.address}`);

  // Create new product
  const manager = "0x6Ca8304ae1973C205c6ac9A6Fb82a017cA800e77";
  const qredoWallet = "0xBA6Aa0Ad8c3ADa57046920135bD323d02dF7E6Ef";

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

  const tx = await shFactory.createProduct(
    "BTC Defensive Spread", // product name
    "BTC/USD", // underlying
    mockUSDC.address, // mock USDC address
    manager,
    shNFT.address, // ERC1155 NFT address
    qredoWallet, // QREDO Wallet
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
