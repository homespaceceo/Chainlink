import * as dotenv from "dotenv";

import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-dependency-compiler";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  dependencyCompiler: {
    paths: [
      '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol'
    ]
  },
  networks: {
    polygon: {
      url: "https://polygon-rpc.com",
      chainId: 137,
      accounts:
        process.env.MATIC_DEPLOYER_PRIVATE_KEY !== undefined
          ? [process.env.MATIC_DEPLOYER_PRIVATE_KEY]
          : [],
    },
    mumbai: {
      url: "https://polygon-testnet.public.blastapi.io",
      chainId: 80001,
      accounts:
        process.env.MATIC_DEPLOYER_PRIVATE_KEY !== undefined
          ? [process.env.MATIC_DEPLOYER_PRIVATE_KEY]
          : [],
    },
  },
};

export default config;
