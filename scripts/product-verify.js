// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  const usdc = "0x07865c6E87B9F70255377e024ace6630C1Eaa37F";

  const manager = "0x6Ca8304ae1973C205c6ac9A6Fb82a017cA800e77";
  const qredoWallet = "0xbba1088BD130AF05AA0ab3EA89464F10C83B984A";
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
      address: "0x380f0103fA96c2EF81161B19a90D90A99ba36a79",
      constructorArguments: [
        "BTC Bullish Spread", // product name
        "BTC/USDC", // underlying symbol
        usdc, // USDC address
        manager, // manager
        "0x0173fA97C69a2EB209D12a77bF376772dD1C5C1F", // NFT address
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