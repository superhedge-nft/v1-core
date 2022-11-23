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
      chainId: 31337,
      forking: {
        enabled: true,
        url: `https://polygon-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY_POLYGON}`
      }
    },
    mumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/${process.env.ALCHEMY_KEY_MUMBAI}`,
      chainId: 80001,
      accounts: [process.env.PRIVATE_KEY]
    },
    polygon: {
      url: `https://polygon-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY_POLYGON}`,
      chainId: 137,
      accounts: [process.env.PRIVATE_KEY]
    },
    moonbase: {
      url: `https://moonbase-alpha.blastapi.io/${process.env.BLAST_PROJECT_ID}`,
      chainId: 1287, // (hex: 0x507),
      accounts: [process.env.PRIVATE_KEY]
    },
    moonbeam: {
      url: `https://moonbeam.blastapi.io/${process.env.BLAST_PROJECT_ID}`, // Insert your RPC URL here
      chainId: 1284, // (hex: 0x504),
      accounts: [process.env.PRIVATE_KEY]
    },
    goerli: {
      url: `https://eth-goerli.g.alchemy.com/v2/${process.env.ALCHEMY_KEY_GOERLI}`,
      chainId: 5,
      accounts: [process.env.PRIVATE_KEY]
    }
  },
  gasReporter: {
    enabled: process.env.GAS_REPORT !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API_KEY,
  }
};
