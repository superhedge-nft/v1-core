// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { ethers } = require("hardhat");

async function main() {
    // Factory contract address
    const factoryAddr = "0x0D09452E92FcF098dAe6152fC27c9ea8424C8559";
    const shFactory = await ethers.getContractAt("SHFactory", factoryAddr);

    // NFT contract address
    const nftAddr = "0xe846De8fd3410028AE8e1778d2E05997C5943A94";

    const usdc = "0x07865c6E87B9F70255377e024ace6630C1Eaa37F";

    const manager = "0x6Ca8304ae1973C205c6ac9A6Fb82a017cA800e77";
    // Qredo Metamask Institutional
    const qredoWallet = "0xbba1088BD130AF05AA0ab3EA89464F10C83B984A"; 

    const productName = "ETH Bullish Spread"

    const issuanceCycle = {
        coupon: 10,
        strikePrice1: 2500,
        strikePrice2: 2700,
        strikePrice3: 0,
        strikePrice4: 0,
        tr1: 11750,
        tr2: 10040,
        issuanceDate: Math.floor(Date.now() / 1000) + 7 * 86400,
        maturityDate: Math.floor(Date.now() / 1000) + 30 * 86400,
        apy: "7-15%",
        uri: "https://gateway.pinata.cloud/ipfs/QmTc4VRM4Ev4aZVY9uhpDQpVxBnJX1rGtV7wGPAiBJaLgc"
    }

    // Create new product
    const tx = await shFactory.createProduct(
        productName, // product name
        "ETH/USDC", // underlying
        usdc, // USDC address on Goerli testnet
        manager,
        nftAddr, // ERC1155 NFT address
        qredoWallet, // QREDO Wallet
        10000, // Max capacity
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
