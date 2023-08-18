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
        url: `https://rpc.mantle.xyz`
      }
    },
    mantleTestnet: {
      url: "https://rpc.testnet.mantle.xyz/",
      chainId: 5001,
      accounts: [process.env.PRIVATE_KEY]
    }
  },
  gasReporter: {
    enabled: process.env.GAS_REPORT !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: {
      mantleTestnet: 'xyz', //random value
    },
    customChains: [
      {
        network: "mantleTestnet",
        chainId: 5001,
        urls: {
          apiURL: "https://explorer.testnet.mantle.xyz/api",
          browserURL: "https://explorer.testnet.mantle.xyz"
        },
      },
    ],
  }
};
