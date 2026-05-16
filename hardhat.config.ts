import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      // Enable via-IR for better optimisation of complex contracts
      viaIR: false,
    },
  },

  paths: {
    sources:   "./contracts",
    tests:     "./test",
    cache:     "./cache",
    artifacts: "./artifacts",
  },

  // Gas reporter is active when REPORT_GAS=true env var is set
  // e.g.  REPORT_GAS=true npx hardhat test
  gasReporter: {
    enabled:  process.env.REPORT_GAS !== undefined,
    currency: "USD",
    gasPrice: 20,
  },

  networks: {
    hardhat: {
      // Give the default accounts plenty of ETH for testing
      accounts: {
        count:              10,
        accountsBalance: "10000000000000000000000", // 10 000 ETH
      },
    },
    // Uncomment and fill in to deploy to a live testnet, e.g. Sepolia:
    // sepolia: {
    //   url:      process.env.SEPOLIA_RPC_URL ?? "",
    //   accounts: process.env.DEPLOYER_PRIVATE_KEY
    //               ? [process.env.DEPLOYER_PRIVATE_KEY]
    //               : [],
    // },
  },
};

export default config;
