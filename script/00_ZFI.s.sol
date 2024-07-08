// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ZFIToken} from "../src/ZFI/ZFIToken.sol";

contract ZfiScript is Script {
    address GOV_ADDRESS;
    address PROXY;
    uint256 deployerPrivateKey;

    function setUp() public {
        GOV_ADDRESS = vm.envAddress("GOV_ADDRESS");
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    }

    function run() public {
        
        vm.startBroadcast(deployerPrivateKey);

        // PROXY = Upgrades.deployUUPSProxy("ZFIToken.sol", abi.encodeCall(ZFIToken.initialize2, (GOV_ADDRESS)));

        address ZFITokenImplementation = address(new ZFIToken());
        PROXY = address(new ERC1967Proxy(ZFITokenImplementation, abi.encodeCall(ZFIToken.initialize2, (GOV_ADDRESS))));

        console2.log("Token address is: ");
        console2.log(PROXY);

        vm.stopBroadcast();
    }

    // function run_old() public {
        
    //     vm.startBroadcast(deployerPrivateKey);

    //     //TODO: fix the deployement via openzeppelin Upgrades
    //     // address proxy = Upgrades.deployUUPSProxy(
    //     // "ZFIToken.sol",
    //     // abi.encodeCall(ZFIToken.initialize2, (TEAM_ADDRESS)));

    //     // In the meantime, unsafe deployment:
    //     address ZFITokenImplementation = address(new ZFIToken());
    //     PROXY = address(new ERC1967Proxy(ZFITokenImplementation, abi.encodeCall(ZFIToken.initialize2, (GOV_ADDRESS))));

    //     //export ZFY_TOKEN_IMPLEMENTATION = ZFITokenImplementation;
    //     console2.log("Token address is: ");
    //     console2.log(PROXY);

    //     vm.stopBroadcast();
    // }
}
