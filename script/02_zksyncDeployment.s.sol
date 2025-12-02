// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ZFIToken} from "../src/ZFI/ZFIToken.sol";
import {RewardTracker} from "../src/staking/RewardTracker.sol";
import {RewardDistributor} from "../src/staking/RewardDistributor.sol";
import {Vester} from "../src/staking/Vester.sol";
import {RewardRouterV2} from "../src/staking/RewardRouterV2.sol";

contract ZkSyncStakingScript is Script {
    // Constants
    address ADMIN_ADDRESS;
    address GOV_ADDRESS;
    address DEPLOYER_ADDRESS;
    uint256 vestingDuration;
    bool HAS_MAX_VESTABLE_AMOUNT;

    // Already Deployed (zkSync):
    address constant rewardTracker = 0xb3DDFd20a48972733f0Bb7D332A09154C5Ed3E1a; // is also the address of stZFI
    address constant rewardDistributor = 0x2E0Ee4811518aa7E68663458D29e81847b9f71a4;
    address constant ZFI = 0x5d0d7BCa050e2E98Fd4A5e8d3bA823B49f39868d;

    // To Be Deployed:
    address vester;
    address rewardRouterV2;

    function setUp() public {
        // update those addresses in the .env
        GOV_ADDRESS = vm.envAddress("GOV_ADDRESS");
        ADMIN_ADDRESS = vm.envAddress("ADMIN_ADDRESS");
        HAS_MAX_VESTABLE_AMOUNT = vm.envBool("HAS_MAX_VESTABLE_AMOUNT"); // set to be false

        // set a duration period (2 weeks)
        vestingDuration = 2 weeks;
    }

    function run() public {
        vm.startBroadcast();
        
        // Deploy Vester
        vester = deployVester();

        // Deploy the RewardRouterV2
        rewardRouterV2 = deployRewardRouterV2();

        // Initialize RewardRouterV2
        RewardRouterV2(rewardRouterV2).initialize(ZFI, rewardTracker, vester);

        // Set the Vester as handler of the RewardTracker
        RewardTracker(rewardTracker).setHandler(address(vester), true);

        // Set the RewardRouterV2 as handler of the RewardTracker
        RewardTracker(rewardTracker).setHandler(rewardRouterV2, true);

        // Set the RewardRouterV2 as handler of the Vester
        Vester(vester).setHandler(rewardRouterV2, true);

        // Choose to set a limit to how much tokens each user can unstake
        Vester(vester).setHasMaxVestableAmount(HAS_MAX_VESTABLE_AMOUNT);

        // To avoid stZFI being tranferable: set RewardTracker in privateTransferMode
        RewardTracker(rewardTracker).setPrivateMode(RewardTracker.Mode.Transfer, true);

        // Set the Admin and Gov rights
        transferAdminAndGovRights();

        // fund the distributor with ZFI
        // set the rewardPerInterval (amount of token to distribute per second)
        
        vm.stopBroadcast();
    }

    function deployVester() public returns(address vesterAddress){
        vesterAddress = address(new Vester("vested ZFI", "vstZFI", vestingDuration, rewardTracker, ZFI, rewardTracker));
        console2.log("Vester is deployed at : ");
        console2.log(vesterAddress);
    }

    function deployRewardRouterV2() public returns(address rewardRouterV2Address){
        rewardRouterV2Address = address(new RewardRouterV2());
        console2.log("RewardRouterV2 is deployed at : ");
        console2.log(rewardRouterV2Address);
    }

    function transferAdminAndGovRights() public {
        // executed at the end of the script set governance to ADMIN_ADDRESS

        // RewardDistributor
        RewardDistributor(rewardDistributor).setAdmin(ADMIN_ADDRESS);
        RewardDistributor(rewardDistributor).setGov(GOV_ADDRESS);

        // RewardTracker
        RewardTracker(rewardTracker).setGov(ADMIN_ADDRESS);
        // Vester
        Vester(vester).setGov(GOV_ADDRESS);
        // RewardRouterV2
        RewardRouterV2(rewardRouterV2).setGov(GOV_ADDRESS);
        // ZYFI token:
        // ZFIToken(ZFI).grantRole(ZFIToken(ZFI).PAUSER_ROLE(), ADMIN_ADDRESS);
        // // keep the Minter role to myself
        // // ZFIToken(ZFI).grantRole(ZFIToken(ZFI).MINTER_ROLE(), ADMIN_ADDRESS);
        // ZFIToken(ZFI).grantRole(ZFIToken(ZFI).DEFAULT_ADMIN_ROLE(), GOV_ADDRESS);
    }
}
