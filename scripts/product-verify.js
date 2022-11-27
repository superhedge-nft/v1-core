// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
    const manager = "0x6Ca8304ae1973C205c6ac9A6Fb82a017cA800e77";
    const qredoWallet = "0xBA6Aa0Ad8c3ADa57046920135bD323d02dF7E6Ef";
    const maxCapacity = 1000000;

    const issuanceCycle = {
        coupon: 10,
        strikePrice1: 25000,
        strikePrice2: 20000,
        strikePrice3: 0,
        strikePrice4: 0,
        uri: "https://gateway.pinata.cloud/ipfs/QmWsa9T8Br16atEbYKit1e9JjXgNGDWn45KcYYKT2eLmSH"
    }

    await hre.run("verify:verify", {
        address: "0xA159624e50e099d896675c7362b5AD11CEa9fD45",
        constructorArguments: [
          "BTC Defensive Spread", // product name
          "BTC/USD", // underlying symbol
          "0x366B9195CBB88080F456e602B2dAc09fC80311BC", // mockUSDC
          manager, // manager
          "0x6B72fE8cA151799D814ECbd10E39854617ca8266", // NFT address
          qredoWallet,
          maxCapacity,
          issuanceCycle
        ],
    });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});