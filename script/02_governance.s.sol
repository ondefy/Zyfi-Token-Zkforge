// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {ZfiGovernor} from "../src/governance/ZfiGovernor.sol";
import {ZFIToken} from "../src/ZFI/ZFIToken.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
//import IVotes
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract GovernanceScript is Script {
    address ADMIN_ADDRESS;
    IVotes token;

    function setUp() public {
        ADMIN_ADDRESS = vm.envAddress("ADMIN_ADDRESS");
        token = IVotes(vm.envAddress("ZFI_ADDRESS"));
    }

    function run() public { //TODO: Governor parameters and Timelock aren't ready for production!!!!!
        vm.startBroadcast();
        // Deploy the Timelock
        /**
     * @dev Initializes the contract with the following parameters:
     *
     * - `minDelay`: initial minimum delay in seconds for operations
     * - `proposers`: accounts to be granted proposer and canceller roles
     * - `executors`: accounts to be granted executor role
     * - `admin`: optional account to be granted admin role; disable with zero address
     *
     * IMPORTANT: The optional admin can aid with initial configuration of roles after deployment
     * without being subject to delay, but this role should be subsequently renounced in favor of
     * administration through timelocked proposals. Previous versions of this contract would assign
     * this admin to the deployer automatically and should be renounced as well.
     */
        address[] memory proposers = new address[](1);
        proposers[0] = ADMIN_ADDRESS;
        address[] memory executors = new address[](1);
        executors[0] = ADMIN_ADDRESS;
    
        TimelockController timelock = new TimelockController(2 days, proposers, executors, ADMIN_ADDRESS);
        address ZfiGovernorAddress = address(new ZfiGovernor(token, timelock));
        vm.stopBroadcast();
    }
}