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

    // Arbitrum Goerli USDC
    const usdc = "0x72A9c57cD5E2Ff20450e409cF6A542f1E6c710fc";

    const manager = "0x6Ca8304ae1973C205c6ac9A6Fb82a017cA800e77";

    // Qredo Metamask Institutional
    const qredoWallet = "0xbba1088BD130AF05AA0ab3EA89464F10C83B984A";

    const productName = "ETH Bullish Spread"
    const issuanceCycle = {
        coupon: 10,
        strikePrice1: 1400,
        strikePrice2: 1600,
        strikePrice3: 0,
        strikePrice4: 0,
        tr1: 11850,
        tr2: 10240,
        issuanceDate: 1681592118,
        maturityDate: 1684184118,
        apy: "9-13%",
        uri: "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH"
    }

    // Create new product
    const tx = await shFactory.createProduct(
        productName, // product name
        "ETH/USDC", // underlying
        usdc, // USDC address on Goerli testnet
        manager,
        shNFT.address, // ERC1155 NFT address
        qredoWallet, // QREDO Wallet
        5000, // Max capacity
        issuanceCycle // First issuance cycle
    );
  
    await tx.wait();
  
    const productAddr = await shFactory.getProduct(productName);

    console.log(`SHProduct deployed at ${productAddr}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
