//TODO: deploy reward router, init it and set it as a handler for the necessary contracts

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Vester} from "src/staking/Vester.sol";
import {RewardRouterV2} from "src/staking/RewardRouterV2.sol";

contract VesterAndRouterScript is Script {
    // Constants
    address GOV_ADDRESS;
    address ZFI;
    address REWARD_TRACKER;
    bool HAS_MAX_VESTABLE_AMOUNT;

    address vester;
    address rewardRouterV2;

    uint256 vestingDuration;

    function setUp() public {
        ZFI = vm.envAddress("ZFI_TOKEN");
        GOV_ADDRESS = vm.envAddress("GOV_ADDRESS");
        HAS_MAX_VESTABLE_AMOUNT = vm.envBool("HAS_MAX_VESTABLE_AMOUNT"); // set to be false
        REWARD_TRACKER = vm.envAddress("REWARD_TRACKER");

        // set a duration period (3 months)
        vestingDuration = 13 weeks;
    }

    function run() public {
        vm.startBroadcast();

        // Deploy Vester
        vester = deployVester();

        // Deploy the RewardRouterV2
        rewardRouterV2 = deployRewardRouterV2();

        // Set the RewardRouterV2 as handler of the Vester
        Vester(vester).setHandler(rewardRouterV2, true);

        // Choose to set a limit to how much tokens each user can unstake
        Vester(vester).setHasMaxVestableAmount(HAS_MAX_VESTABLE_AMOUNT);

        // Initialize RewardRouterV2
        RewardRouterV2(rewardRouterV2).initialize(ZFI, REWARD_TRACKER, vester);

        //----------------------------------------------------

        // Set the RewardRouterV2 as handler of the Vester
        Vester(vester).setHandler(rewardRouterV2, true);

        //-----------------------

        // RewardRouterV2
        RewardRouterV2(rewardRouterV2).setGov(GOV_ADDRESS);

        Vester(vester).setGov(GOV_ADDRESS);

        //DAO:

        // Set the RewardRouterV2 as handler of the RewardTracker
        // RewardTracker(rewardTracker).setHandler(rewardRouterV2, true);//TODO: DAO

        // Set the Vester as handler of the RewardTracker
        // RewardTracker(rewardTracker).setHandler(address(vester), true);//TODO: DAO        
    }

    function deployVester() public returns(address vesterAddress){
        vesterAddress = address(new Vester("vested ZFI", "vstZFI", vestingDuration, REWARD_TRACKER, ZFI, REWARD_TRACKER));
        console2.log("Vester is deploy at : ");
        console2.log(vesterAddress);
    }

    function deployRewardRouterV2() public returns(address rewardRouterV2Address){
        rewardRouterV2Address = address(new RewardRouterV2());
        console2.log("RewardRouterV2 is deploy at : ");
        console2.log(rewardRouterV2Address);
    }
}