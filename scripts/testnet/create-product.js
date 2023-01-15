// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { ethers, upgrades } = require("hardhat");

async function main() {
    const factoryAddr = "0x5662A56F45C8744e3703AdE354209d5526C4F9C5";
    const shFactory = await ethers.getContractAt("SHFactory", factoryAddr);

    const nftAddr = "0x0173fA97C69a2EB209D12a77bF376772dD1C5C1F";

    const usdc = "0x07865c6E87B9F70255377e024ace6630C1Eaa37F";

    const manager = "0x6Ca8304ae1973C205c6ac9A6Fb82a017cA800e77";
    const qredoWallet = "0xbba1088BD130AF05AA0ab3EA89464F10C83B984A"; // Qredo Metamask Institutional

    const productName = "ETH Bullish Spread"
    const issuanceCycle = {
        coupon: 20,
        strikePrice1: 1200,
        strikePrice2: 1400,
        strikePrice3: 0,
        strikePrice4: 0,
        uri: "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH"
    }

    // Create new product
    const tx = await shFactory.createProduct(
        productName, // product name
        "ETH/USDC", // underlying
        usdc, // USDC address on Goerli testnet
        manager,
        nftAddr, // ERC1155 NFT address
        qredoWallet, // QREDO Wallet
        1000000, // Max capacity
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
