require("@nomicfoundation/hardhat-toolbox");

require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: '0.8.9',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      }
    },
  },
  networks: {
    /* hardhat: {
      forking: {
        url: `https://moonbeam.blastapi.io/${process.env.BLAST_PROJECT_ID}`
      }
    }, */
    moonbase: {
      url: `https://moonbase-alpha.blastapi.io/${process.env.BLAST_PROJECT_ID}`,
      chainId: 1287, // (hex: 0x507),
      accounts: [process.env.PRIVATE_KEY]
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
