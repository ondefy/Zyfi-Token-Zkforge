// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ODYToken} from "../src/ody/ODYToken.sol";

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
        // "ODYToken.sol",
        // abi.encodeCall(ODYToken.initialize2, (TEAM_ADDRESS)));

        // In the meantime, unsafe deployment:
        address ondefyTokenImplementation = address(new ODYToken());
        PROXY = address(new ERC1967Proxy(ondefyTokenImplementation, abi.encodeCall(ODYToken.initialize2, (TEAM_ADDRESS))));
        vm.stopBroadcast();
    }
}
