// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {RewardTracker} from "src/staking/RewardTracker.sol";
import {ZFI_test, ZFIToken} from "./00_ZFI.t.sol";
import {RewardDistributor} from "src/staking/RewardDistributor.sol";

contract RewardTracker_Tester is Test {
    address TEAM_ADDRESS = makeAddr("TEAM_ADDRESS");
    address DEPLOYER_ADDRESS = makeAddr("DEPLOYER_ADDRESS");
    address USER1 = makeAddr("USER1");
    ZFIToken zfiToken;
    RewardTracker rewardTracker;
    ZFI_test zfiDeployer = new ZFI_test();
    address[] depositTokens;
    address DISTRIBUTOR;

    function setUp() public {
        deal(DEPLOYER_ADDRESS, 2 ether);
        deal(TEAM_ADDRESS, 2 ether);
        deal(USER1, 2 ether);

        // Deploy ZFI:
        address zfiTokenAddress = zfiDeployer.deploy_ZFI();
        zfiToken = ZFIToken(zfiTokenAddress);

        //deploy RewardTracker:
        rewardTracker = RewardTracker(RewardTracker_Tester.deployRewardTracker(zfiTokenAddress));
        
        DISTRIBUTOR = deployRewardDistributor();
        vm.startPrank(DEPLOYER_ADDRESS);
        rewardTracker.initialize(DISTRIBUTOR);
        vm.stopPrank();
    }

    function deployRewardTracker(address zfiTokenAddress) public returns(address rewardTrackerAddress){
        vm.startPrank(DEPLOYER_ADDRESS);
        rewardTrackerAddress = address(new RewardTracker("staked ZFI", "stZFY", zfiTokenAddress));
        console2.log(rewardTrackerAddress);
        vm.stopPrank();
    }

    function deployRewardDistributor() public returns(address rewardDistributorAddress){
        vm.startPrank(DEPLOYER_ADDRESS);
        rewardDistributorAddress = address(new RewardDistributor(address(zfiToken), address(rewardTracker)));
        console2.log(rewardDistributorAddress);
        vm.stopPrank();
    }

    function test_isInitialized() public view {
        address owner = rewardTracker.gov();
        assertEq(owner, DEPLOYER_ADDRESS);

        assertEq(rewardTracker.isInitialized(), true);
        assertEq(rewardTracker.distributor(), DISTRIBUTOR);
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

    function test_stake() public setGov(TEAM_ADDRESS) {
        deal(address(zfiToken), USER1, 2 ether);
        // setDepositToken
        // vm.startPrank(TEAM_ADDRESS);
        // rewardTracker.setDepositToken(address(zfiToken), true);
        // vm.stopPrank();

        vm.startPrank(USER1);
            zfiToken.approve(address(rewardTracker), 2 ether);
            rewardTracker.stake(2 ether);
        vm.stopPrank();
        uint256 balance = rewardTracker.balanceOf(USER1);
        assertEq(balance, 2 ether);
    }

    //TODO: test privateTransferMode so stZFI isn't transferable but for handlers

    //TODO: test more integration (boost + rewards via stake)
    //
    // tokensPerInterval
    // updateRewards

    // + restaked asset for rewards in ETH and rewards in ZFI

}
