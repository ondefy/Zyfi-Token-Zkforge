// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {RewardTracker} from "src/staking/RewardTracker.sol";
import {ZYFI_test, ZYFIToken} from "./00_ZYFI.t.sol";
import {esZYFI_test, esZYFIToken} from "./01_esZYFI.t.sol";
import {RewardTracker_Tester, RewardTracker} from "./02_RewardTracker.t.sol";
import {RewardDistributor} from "src/staking/RewardDistributor.sol";

contract RewardDistributor_Tester is Test {
    address TEAM_ADDRESS = makeAddr("TEAM_ADDRESS");
    address DEPLOYER_ADDRESS = makeAddr("DEPLOYER_ADDRESS");
    address USER1 = makeAddr("USER1");
    ZYFIToken zyfiToken;
    esZYFIToken esZyfiToken;
    RewardTracker rewardTracker;
    ZYFI_test zifyDeployer = new ZYFI_test();
    esZYFI_test esZifyDeployer = new esZYFI_test();
    RewardTracker_Tester rewardTrackerDeployer = new RewardTracker_Tester();
    address[] depositTokens;
    RewardDistributor rewardDistributor;

    function setUp() public {
        deal(DEPLOYER_ADDRESS, 2 ether);
        deal(TEAM_ADDRESS, 2 ether);
        deal(USER1, 2 ether);

        vm.startPrank(DEPLOYER_ADDRESS);
        // Deploy ZYFI:
        address zyfiTokenAddress = zifyDeployer.deploy_ZYFI();
        zyfiToken = ZYFIToken(zyfiTokenAddress);

        // Deploy esZYFI:
        address esZyfiTokenAddress = esZifyDeployer.deploy_esZYFI();
        esZyfiToken = esZYFIToken(esZyfiTokenAddress);
        vm.stopPrank();
        //deploy RewardTracker:
        rewardTracker = RewardTracker(rewardTrackerDeployer.deployRewardTracker());
        
        depositTokens.push(zyfiTokenAddress);
        vm.startPrank(DEPLOYER_ADDRESS);
        rewardTracker.initialize(depositTokens, makeAddr("DISTRIBUTOR"));    
        
        // constructor(address _rewardToken, address _rewardTracker) {
        rewardDistributor = RewardDistributor(deployRewardDistributor());
        vm.stopPrank();
    }

    function deployRewardDistributor() public returns(address rewardDistributorAddress){
        vm.startPrank(DEPLOYER_ADDRESS);
        rewardDistributorAddress = address(new RewardDistributor(address(esZyfiToken), address(rewardTracker)));
        vm.stopPrank();
    }

    function test_setGov() public setGov(TEAM_ADDRESS) {
        address owner = rewardTracker.gov();
        assertEq(owner, TEAM_ADDRESS);
    }

    modifier setGov(address _newGov) {
        vm.startPrank(DEPLOYER_ADDRESS);
            rewardTracker.setGov(_newGov);
        vm.stopPrank();
        _;
    }

    // function test_stake() public setGov(TEAM_ADDRESS) {
    //     deal(address(zyfiToken), USER1, 2 ether);
    //     // setDepositToken
    //     vm.startPrank(TEAM_ADDRESS);
    //     rewardTracker.setDepositToken(address(zyfiToken), true);
    //     vm.stopPrank();

    //     vm.startPrank(USER1);
    //         zyfiToken.approve(address(rewardTracker), 2 ether);
    //         rewardTracker.stake(address(zyfiToken), 2 ether);
    //     vm.stopPrank();
    //     uint256 balance = rewardTracker.balanceOf(USER1);
    //     assertEq(balance, 2 ether);
    // }

    //TODO: unstake

    //TODO: test more integration (boost + rewards via stake)
    //
    // tokensPerInterval
    // updateRewards

    // + restaked asset for rewards in ETH and rewards in ZYFI

}
