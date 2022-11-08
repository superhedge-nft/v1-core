const hre = require("hardhat");

async function main() {
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

    await hre.run("verify:verify", {
        address: "0xb7149da8F649A76294a1Ff8645289a7aC850cB29",
        constructorArguments: [
            "BTC Defensive Spread", // product name
            "BTC/USD", // underlying
            deployer, // QREDO Wallet
            nftAddr, // ERC1155 NFT address
            1000000, // Max capacity
            issuanceCycle // First issuance cycle
        ],
    });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});