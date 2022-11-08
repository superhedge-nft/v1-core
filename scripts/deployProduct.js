const { ethers } = require("hardhat");

async function main() {
    const factoryAddr = "0xac39D351089681a6116D19BE1df4Bf94DAdbCC4C";
    const nftAddr = "0x7137d5375478630E95768ec0afb4f1766a15b54C";
    const deployer = "0x488177c42bD58104618cA771A674Ba7e4D5A2FBB";

    const issuanceCycle = {
        coupon: 10,
        strikePrice1: 25000,
        strikePrice2: 20000,
        strikePrice3: 0,
        strikePrice4: 0,
        uri: "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH"
    }

    const shFactory = await ethers.getContractAt("SHFactory", factoryAddr);

    const tx = await shFactory.createProduct(
        "BTC Defensive Spread", // product name
        "BTC/USD", // underlying
        deployer, // QREDO Wallet
        nftAddr, // ERC1155 NFT address
        1000000, // Max capacity
        issuanceCycle // First issuance cycle
    );
    
    await tx.wait();
    
    const productAddr = await shFactory.getProduct("BTC Defensive Spread");

    /* const SHProduct = await ethers.getContractFactory("SHProduct");
    const shProduct = await SHProduct.deploy(
        "BTC Defensive Spread", // product name
        "BTC/USD", // underlying
        deployer.address, // QREDO Wallet
        nftAddr, // ERC1155 NFT address
        1000000, // Max capacity
        issuanceCycle // First issuance cycle
    );
    await shProduct.deployed(); */

    console.log(`SHProduct deployed at ${productAddr}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
