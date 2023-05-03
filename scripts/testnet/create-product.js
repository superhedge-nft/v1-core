// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { ethers, upgrades } = require("hardhat");

async function main() {
    const factoryAddr = "0x4562b4A667BabA8EE3f2BcdED65ff916556C383E";
    const shFactory = await ethers.getContractAt("SHFactory", factoryAddr);

    const nftAddr = "0x539890cB8E365495908E844e42ee36E0e6b354B4";

    const usdc = "0x3799D95Ee109129951c6b31535b2B5AA6dbF108c";

    const manager = "0x6Ca8304ae1973C205c6ac9A6Fb82a017cA800e77";
    // Qredo Metamask Institutional
    const qredoWallet = "0xbba1088BD130AF05AA0ab3EA89464F10C83B984A";

    const productName = "ETH Bullish Spread";

    const issuanceCycle = {
        coupon: 10,
        strikePrice1: 1400,
        strikePrice2: 1600,
        strikePrice3: 0,
        strikePrice4: 0,
        tr1: 11750,
        tr2: 10040,
        issuanceDate: 1683244800,
        maturityDate: 1685404800,
        apy: "7-15%",
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
