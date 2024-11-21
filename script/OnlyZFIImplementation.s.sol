// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {ZFIToken} from "../src/ZFI/ZFIToken.sol";

contract ZfiImplementationScript is Script {
    address ADMIN_ADDRESS;

    function setUp() public {
        ADMIN_ADDRESS = vm.envAddress("ADMIN_ADDRESS");
    }

    function run() public {
        vm.startBroadcast();
        address ZFITokenImplementation = address(new ZFIToken());
        console2.log("Token address is: ");
        console2.log(ZFITokenImplementation);

        vm.stopBroadcast();
    }
}