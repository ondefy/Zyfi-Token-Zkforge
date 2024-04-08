// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ODYToken} from "../src/ody/ODYToken.sol";

contract CounterScript is Script {
    address TEAM_ADDRESS;
    address DEPLOYER_ADDRESS;

    function setUp() public {
        TEAM_ADDRESS = vm.envAddress("TEAM_ADDRESS");
        DEPLOYER_ADDRESS = vm.envAddress("DEPLOYER_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
    }

    function run() public {
        vm.broadcast();
        //TODO
        address proxy = Upgrades.deployBeacon(
        "ODYToken.sol",
        TEAM_ADDRESS,
        abi.encodeCall(ODYToken.initialize, ("arguments for the initialize function"))
        );
    }
}
