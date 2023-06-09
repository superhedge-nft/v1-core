// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { ethers, upgrades } = require("hardhat");

async function main() {
    const factoryAddr = "0x467b31Caa1f26bCe5aE09C2b629026eE03C34C07";
    const shFactory = await ethers.getContractAt("SHFactory", factoryAddr);

    const nftAddr = "0x9CC080062ddd770ef30C7a33a5764174FB6d022C";

    const usdc = "0x3799D95Ee109129951c6b31535b2B5AA6dbF108c";

    const manager = "0x6Ca8304ae1973C205c6ac9A6Fb82a017cA800e77";
    // Qredo Metamask Institutional
    const qredoWallet = "0xbba1088BD130AF05AA0ab3EA89464F10C83B984A";

    const productName = "ETH Bullish Spread";

    const issuanceCycle = {
        coupon: 10,
        strikePrice1: 1600,
        strikePrice2: 1800,
        strikePrice3: 0,
        strikePrice4: 0,
        tr1: 11750,
        tr2: 10040,
        issuanceDate: Math.floor(Date.now() / 1000) + 1 * 86400,
        maturityDate: Math.floor(Date.now() / 1000) + 30 * 86400,
        apy: "8-14%",
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
