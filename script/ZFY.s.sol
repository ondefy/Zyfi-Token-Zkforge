// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ZFIToken} from "../src/ZFI/ZFIToken.sol";

contract ZfyScript is Script {
    address TEAM_ADDRESS;
    address DEPLOYER_ADDRESS;
    address PROXY;

    function setUp() public {
        TEAM_ADDRESS = vm.envAddress("TEAM_ADDRESS");
        DEPLOYER_ADDRESS = vm.envAddress("DEPLOYER_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
    }

    function run() public {
        
        vm.broadcast();
        //TODO: fix the deployement via openzeppelin Upgrades
        // address proxy = Upgrades.deployUUPSProxy(
        // "ZFIToken.sol",
        // abi.encodeCall(ZFIToken.initialize2, (TEAM_ADDRESS)));

        // In the meantime, unsafe deployment:
        address ZFITokenImplementation = address(new ZFIToken());
        PROXY = address(new ERC1967Proxy(ZFITokenImplementation, abi.encodeCall(ZFIToken.initialize2, (TEAM_ADDRESS))));
        //export ZFY_TOKEN_IMPLEMENTATION = ZFITokenImplementation;
        vm.stopBroadcast();
    }
}
