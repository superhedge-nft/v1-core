// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { ethers, upgrades } = require("hardhat");

async function main() {
    const factoryAddr = "0x7CfDE50B62fDA64Ea64784cA2244D0f956C12264";
    const shFactory = await ethers.getContractAt("SHFactory", factoryAddr);

    const nftAddr = "0x810F98442c3349553031d70F8E510841104bd857";

    const usdc = "0x72A9c57cD5E2Ff20450e409cF6A542f1E6c710fc";

    const manager = "0x6Ca8304ae1973C205c6ac9A6Fb82a017cA800e77";
    const qredoWallet = "0xbba1088BD130AF05AA0ab3EA89464F10C83B984A"; // Qredo Metamask Institutional

    const productName = "BTC Bearish Spread"

    const issuanceCycle = {
        coupon: 20,
        strikePrice1: 28000,
        strikePrice2: 26000,
        strikePrice3: 0,
        strikePrice4: 0,
        tr1: 10850,
        tr2: 11240,
        issuanceDate: 1682592118,
        maturityDate: 1685184118,
        apy: "8-13%",
        uri: "https://gateway.pinata.cloud/ipfs/QmfXCbDZMpNhPLxxNHuxp7LESMadb9sd3Qkt33Bd9pYJBm"
    }

    // Create new product
    const tx = await shFactory.createProduct(
        productName, // product name
        "BTC/USDC", // underlying
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
