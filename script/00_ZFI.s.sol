// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ZFIToken} from "../src/ZFI/ZFIToken.sol";

contract ZfiScript is Script {
    address GOV_ADDRESS;
    address PROXY;

    function setUp() public {}

    function run() public {
        
        vm.startBroadcast();
        GOV_ADDRESS = msg.sender;

        address ZFITokenImplementation = address(new ZFIToken());
        PROXY = address(new ERC1967Proxy(ZFITokenImplementation, abi.encodeCall(ZFIToken.initialize2, (GOV_ADDRESS))));
        console2.log("Token address is: ");
        console2.log(PROXY);
        vm.stopBroadcast();
    }
}