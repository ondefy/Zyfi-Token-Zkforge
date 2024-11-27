// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ZFIToken} from "../src/ZFI/ZFIToken.sol";

contract ZfiUpgradeScript is Script {
    address DEPLOYER_ADDRESS = 0xA47dF9473fF4084BA4d11271cA8a470361D77a09;
    address proxy_address;
    address TEAM_ADDRESS = 0x336044E117fA0e786eE1A58b4a54a9969AA288De;
    address newImplementation = 0x9f4D380c867EBaed8140C332c78BF32Eb52A01Fb;

    function setUp() public {
        proxy_address = vm.envAddress("ZFI_TOKEN");
    }

    function run() public {
        vm.startBroadcast();
        ZFIToken proxy_token = ZFIToken(proxy_address);
        proxy_token.upgradeToAndCall(newImplementation, "");
        transferMinterRight();
        vm.stopBroadcast();
    }

    function transferMinterRight() public {
        vm.startBroadcast();
        ZFIToken proxy_token = ZFIToken(proxy_address);
        proxy_token.grantRole(proxy_token.PAUSER_ROLE(), TEAM_ADDRESS);
        proxy_token.grantRole(proxy_token.MINTER_ROLE(), TEAM_ADDRESS);
        proxy_token.revokeRole(proxy_token.MINTER_ROLE(), DEPLOYER_ADDRESS);
        proxy_token.revokeRole(proxy_token.PAUSER_ROLE(), DEPLOYER_ADDRESS);
        proxy_token.revokeRole(proxy_token.DEFAULT_ADMIN_ROLE(), DEPLOYER_ADDRESS);
        vm.stopBroadcast();
    }
}