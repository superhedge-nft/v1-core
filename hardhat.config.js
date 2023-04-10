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
        url: `https://arb-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY_ARBITRUM_MAINNET}`,
        blockNumber: 77763335
      }
    },
    arbitrumGoerli: {
      url: `https://arb-goerli.g.alchemy.com/v2/${process.env.ALCHEMY_KEY_ARBITRUM_GOERLI}`,
      chainId: 421613,
      accounts: [process.env.PRIVATE_KEY]
    },
    arbitrumOne: {
      url: `https://arb-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY_ARBITRUM_MAINNET}`,
      chainId: 42161,
      accounts: [process.env.PRIVATE_KEY]
    }
  },
  gasReporter: {
    enabled: process.env.GAS_REPORT !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ARBISCAN_API_KEY,
  }
};
