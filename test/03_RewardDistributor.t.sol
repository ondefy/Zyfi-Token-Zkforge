// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {RewardTracker} from "src/staking/RewardTracker.sol";
import {ZFI_test, ZFIToken} from "./00_ZFI.t.sol";
import {RewardTracker_Tester, RewardTracker} from "./02_RewardTracker.t.sol";
import {RewardDistributor} from "src/staking/RewardDistributor.sol";

contract RewardDistributor_Tester is Test {
    address TEAM_ADDRESS = makeAddr("TEAM_ADDRESS");
    address DEPLOYER_ADDRESS = makeAddr("DEPLOYER_ADDRESS");
    address USER1 = makeAddr("USER1");
    address USER2 = makeAddr("USER2");
    ZFIToken zfiToken;
    RewardTracker rewardTracker;
    ZFI_test zfiDeployer = new ZFI_test();
    RewardTracker_Tester rewardTrackerDeployer = new RewardTracker_Tester();
    address[] depositTokens;
    RewardDistributor rewardDistributor;

    function setUp() public {
        deal(DEPLOYER_ADDRESS, 2 ether);
        deal(TEAM_ADDRESS, 2 ether);
        deal(USER1, 2 ether);

        // Deploy ZFI:
        address zfiTokenAddress = zfiDeployer.deploy_ZFI();
        zfiToken = ZFIToken(zfiTokenAddress);
        
        //deploy RewardTracker:
        rewardTracker = RewardTracker(rewardTrackerDeployer.deployRewardTracker());
        console2.log(address(rewardTracker)); // 0xa88CdF6f746fdB9dD637666e63a54009A62B8162
        
        depositTokens.push(zfiTokenAddress);
        
        // rewardDsitributor is deployed with ZFI as the reward token
        rewardDistributor = RewardDistributor(deployRewardDistributor());

        vm.prank(DEPLOYER_ADDRESS);
        rewardTracker.initialize(depositTokens, address(rewardDistributor)); 
    }

    function deployRewardDistributor() public returns(address rewardDistributorAddress){
        vm.startPrank(DEPLOYER_ADDRESS);
        rewardDistributorAddress = address(new RewardDistributor(address(zfiToken), address(rewardTracker)));
        console2.log(rewardDistributorAddress);
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


    function test_distributeRewardsOneUser() public setGov(TEAM_ADDRESS) {
        uint256 distributorAmount = 10000 ether;
        uint256 userAmount = 10 ether;
        uint256 tokenPerInterval = 1 ether;
        //setAdmin
        vm.prank(DEPLOYER_ADDRESS);
        rewardDistributor.setAdmin(TEAM_ADDRESS);
        //updateLastDistributionTime
        vm.startPrank(TEAM_ADDRESS);
        rewardDistributor.updateLastDistributionTime();
        //setTokensPerInterval
        rewardDistributor.setTokensPerInterval(tokenPerInterval);
        // mint to ZFI tokens to the dirstibutor
        deal(address(zfiToken), address(rewardDistributor), distributorAmount);

        // user deposit in stZFI
        deal(address(zfiToken), USER1, userAmount);
        // deposit in rewardTracker
        vm.startPrank(USER1);
        zfiToken.approve(address(rewardTracker), userAmount);
        rewardTracker.stake(address(zfiToken), userAmount);
        uint256 userBalance = zfiToken.balanceOf(USER1);
        assertEq(0, userBalance);
        
        vm.warp(block.timestamp+1);
        // assert with pendingRewards
        uint256 pendingRewards = rewardDistributor.pendingRewards();
        assertEq(1 ether, pendingRewards);

        uint256 claimRewards = rewardTracker.claim(USER1);
        assertEq(1 ether, claimRewards);

        userBalance = rewardTracker.balanceOf(USER1);
        assertEq(userBalance + pendingRewards, userBalance);
        assertEq(userAmount + tokenPerInterval, userBalance);
    }

    // multiple users
    function test_distributeRewardsMultipleUsers() public setGov(TEAM_ADDRESS) {
        uint256 distributorAmount = 10000 ether;
        uint256 userAmount = 10 ether;
        uint256 tokenPerInterval = 1 ether;
        //setAdmin
        vm.prank(DEPLOYER_ADDRESS);
        rewardDistributor.setAdmin(TEAM_ADDRESS);
        //updateLastDistributionTime
        vm.startPrank(TEAM_ADDRESS);
        rewardDistributor.updateLastDistributionTime();
        //setTokensPerInterval
        rewardDistributor.setTokensPerInterval(tokenPerInterval);
        // mint to ZFI tokens to the dirstibutor
        deal(address(zfiToken), address(rewardDistributor), distributorAmount);

        // USER1 deposit in stZFI
        deal(address(zfiToken), USER1, userAmount);
        // deposit in rewardTracker
        vm.startPrank(USER1);
        zfiToken.approve(address(rewardTracker), userAmount);
        rewardTracker.stake(address(zfiToken), userAmount);
        uint256 userBalance = zfiToken.balanceOf(USER1);
        assertEq(0, userBalance);

        // USER2 deposit in stZFI
        deal(address(zfiToken), USER2, userAmount);
        // deposit in rewardTracker
        vm.startPrank(USER2);
        zfiToken.approve(address(rewardTracker), userAmount);
        rewardTracker.stake(address(zfiToken), userAmount);
        userBalance = zfiToken.balanceOf(USER2);
        assertEq(0, userBalance);
        
        vm.warp(block.timestamp+1);
        // assert with pendingRewards
        uint256 pendingRewards = rewardDistributor.pendingRewards();
        assertEq(1 ether, pendingRewards);

        vm.startPrank(USER1);
        uint256 claimRewards = rewardTracker.claim(USER1);
        assertEq(tokenPerInterval / 2, claimRewards);

        userBalance = rewardTracker.balanceOf(USER1);
        assertEq(userAmount + pendingRewards/2, userBalance);
        assertEq(userAmount + tokenPerInterval/2, userBalance);

        vm.startPrank(USER2);

        // pendingRewards = rewardDistributor.pendingRewards();
        // assertEq(0.5 ether, pendingRewards);

        uint256 claimableAmount = rewardTracker.claimable(USER2);
        assertEq(tokenPerInterval/2, claimableAmount);

        claimRewards = rewardTracker.claim(USER2);
        assertEq(tokenPerInterval / 2, claimRewards);


        userBalance = rewardTracker.balanceOf(USER2);
        assertEq(userAmount + pendingRewards/2, userBalance);
        assertEq(userAmount + tokenPerInterval/2, userBalance);
    }
}
