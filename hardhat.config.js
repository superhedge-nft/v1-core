require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: '0.8.14',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      }
    },
  },
  networks: {
    hardhat: {
      chainId: 1337,
      forking: {
        enabled: true,
        url: `https://rpc.ankr.com/moonbeam`
      }
    },
    moonbase: {
      url: `https://moonbase-alpha.blastapi.io/${process.env.BLAST_PROJECT_ID}`,
      // url: `https://rpc.api.moonbase.moonbeam.network`,
      chainId: 1287, // (hex: 0x507),
      accounts: [process.env.PRIVATE_KEY],
      gasPrice: 1000000000,
    },
    moonbeam: {
      url: `https://moonbeam.blastapi.io/${process.env.BLAST_PROJECT_ID}`, // Insert your RPC URL here
      chainId: 1284, // (hex: 0x504),
      accounts: [process.env.PRIVATE_KEY]
    }
  },
  gasReporter: {
    enabled: process.env.GAS_REPORT !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.MOONSCAN_API_KEY,
  }
};
