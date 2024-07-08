import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@matterlabs/hardhat-zksync";

require("dotenv").config();

const config: HardhatUserConfig = {
    solidity: "0.8.24",
    networks: {
        zksyncSepolia: {
            url: "https://sepolia.era.zksync.dev",
            ethNetwork: "sepolia",
            zksync: true,
            accounts: [`${process.env.WALLET_PRIVATE_KEY}`],
        },
    },
    defaultNetwork: "zksyncSepolia",
    paths: {
        sources: "./src",
    },
};

export default config;
