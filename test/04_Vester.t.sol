// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {ZFI_test, ZFIToken} from "./00_ZFI.t.sol";
import {Vester} from "src/staking/Vester.sol";
import {RewardTracker_Tester, RewardTracker, RewardDistributor} from "./02_RewardTracker.t.sol";

contract Vester_Tester is Test {
    address TEAM_ADDRESS = makeAddr("TEAM_ADDRESS");
    address DEPLOYER_ADDRESS = makeAddr("DEPLOYER_ADDRESS");
    address USER1 = makeAddr("USER1");
    address HANDLER = makeAddr("HANDLER");
    uint256 vestingDuration = 1 weeks;
    ZFIToken zfiToken;
    RewardTracker rewardTracker;
    ZFI_test zfiDeployer = new ZFI_test();
    address[] depositTokens;
    RewardTracker_Tester rewardTrackerDeployer = new RewardTracker_Tester();
    Vester vester;
    address DISTRIBUTOR;

    function setUp() public {
        deal(DEPLOYER_ADDRESS, 2 ether);
        deal(TEAM_ADDRESS, 2 ether);
        deal(USER1, 2 ether);


        // Deploy ZFI:
        address zfiTokenAddress = zfiDeployer.deploy_ZFI();
        zfiToken = ZFIToken(zfiTokenAddress);

        //deploy RewardTracker:
        rewardTracker = RewardTracker(rewardTrackerDeployer.deployRewardTracker(zfiTokenAddress));
        vm.prank(DEPLOYER_ADDRESS);
        rewardTracker.setGov(TEAM_ADDRESS);

        // Enable deposit of stZFI
        DISTRIBUTOR = deployRewardDistributor();

        vm.prank(TEAM_ADDRESS);
        rewardTracker.initialize(DISTRIBUTOR);

        vm.prank(DEPLOYER_ADDRESS);
        vester = new Vester("staked ZFI", "stZFI", vestingDuration, address(rewardTracker), zfiTokenAddress, address(rewardTracker));
        vm.prank(TEAM_ADDRESS);
        // let the vester unstake for users
        rewardTracker.setHandler(address(vester), true);
    }

    function deployRewardDistributor() public returns(address rewardDistributorAddress){
        vm.startPrank(DEPLOYER_ADDRESS);
        rewardDistributorAddress = address(new RewardDistributor(address(zfiToken), address(rewardTracker)));
        console2.log(rewardDistributorAddress);
        vm.stopPrank();
    }

    //TODO: hasRewardTracker

    function test_setGov() public setGov(TEAM_ADDRESS) {
        address owner = vester.gov();
        assertEq(owner, TEAM_ADDRESS);
    }

    modifier setGov(address _newGov) {
        vm.startPrank(DEPLOYER_ADDRESS);
            vester.setGov(_newGov);
        vm.stopPrank();
        _;
    }

    function test_deposit() public setGov(TEAM_ADDRESS){
        uint256 amount = 2 ether;
        deal(address(zfiToken), USER1, amount);
        // deposit in rewardTracker
        vm.startPrank(USER1);
        zfiToken.approve(address(rewardTracker), amount);
        rewardTracker.stake(amount);
        vm.stopPrank();
        console2.log(vester.gov());
        vm.prank(TEAM_ADDRESS);
        vester.setHasMaxVestableAmount(false);

        vm.startPrank(USER1);
            rewardTracker.approve(address(vester), amount);
            vester.deposit(amount);
        vm.stopPrank();
        assertEq(vester.balanceOf(USER1), amount); 
    }

    function test_deposit_MaxVestableAmount() public setGov(TEAM_ADDRESS){
        uint256 transferredCumulativeRewards = 10 ether;
        uint256 bonusRewards = 15 ether;
        uint256 sumRewards = transferredCumulativeRewards + bonusRewards;
        uint256 amount = sumRewards;
        deal(address(zfiToken), USER1, amount);
        // deposit in rewardTracker
        vm.startPrank(USER1);
        zfiToken.approve(address(rewardTracker), amount);
        rewardTracker.stake(amount);
        vm.stopPrank();
        vm.startPrank(TEAM_ADDRESS);
        vester.setHasMaxVestableAmount(true);
        vester.setHandler(HANDLER, true);
        vm.startPrank(HANDLER);
        vester.setTransferredCumulativeRewards(USER1, transferredCumulativeRewards);
        //vester.setCumulativeRewardDeductions(USER1, cumulativeRewardDeductions);
        vester.setBonusRewards(USER1, bonusRewards);
        vm.startPrank(USER1);
            rewardTracker.approve(address(vester), sumRewards);
            vester.deposit(sumRewards);
        vm.stopPrank();
        assertEq(vester.balanceOf(USER1), sumRewards); 
    }

    function test_deposit_OneClaim() public setGov(TEAM_ADDRESS){
        uint256 transferredCumulativeRewards = 10 ether;
        uint256 bonusRewards = 15 ether;
        uint256 sumRewards = transferredCumulativeRewards + bonusRewards;
        deal(address(zfiToken), USER1, sumRewards);
        // deposit in rewardTracker
        vm.startPrank(USER1);
        zfiToken.approve(address(rewardTracker), sumRewards);
        rewardTracker.stake(sumRewards);
        vm.startPrank(TEAM_ADDRESS);
        vester.setHasMaxVestableAmount(true);
        vester.setHandler(HANDLER, true);
        vm.startPrank(HANDLER);
        vester.setTransferredCumulativeRewards(USER1, transferredCumulativeRewards);
        vester.setBonusRewards(USER1, bonusRewards);
        vm.startPrank(USER1);
            // no need to approve
            vester.deposit(sumRewards);
        vm.stopPrank();
        assertEq(vester.balanceOf(USER1), sumRewards);
        uint256 vesterStakedBalance = rewardTracker.balanceOf(address(vester));
        assertEq(0, vesterStakedBalance);
        uint256 vesterStakedAmount = rewardTracker.stakedAmounts(address(vester));
        assertEq(0, vesterStakedAmount);
        uint256 userStakedAmount = rewardTracker.stakedAmounts(USER1);
        assertEq(0, userStakedAmount);
        vm.warp(block.timestamp + 1 + vestingDuration);
        uint256 claimableAmount = vester.claimable(USER1);
        console2.log(claimableAmount);
        vm.startPrank(USER1);
            vester.claim();
        vm.stopPrank();
        uint256 vesterBalance = vester.balanceOf(USER1);
        assertEq(0, vesterBalance);
        uint256 claimedBalance = zfiToken.balanceOf(USER1);
        assertEq(sumRewards, claimedBalance);
    }

    //TODO: deposit in Vester and claim after 2, 3 and 6 months
    function test_deposit_MultipleClaims() public setGov(TEAM_ADDRESS){
        uint256 transferredCumulativeRewards = 70 ether;
        uint256 bonusRewards = 0 ether;
        uint256 sumRewards = transferredCumulativeRewards + bonusRewards;
        deal(address(zfiToken), USER1, sumRewards);
        // deposit in rewardTracker
        vm.startPrank(USER1);
        zfiToken.approve(address(rewardTracker), sumRewards);
        rewardTracker.stake(sumRewards);
        vm.startPrank(TEAM_ADDRESS);
        vester.setHasMaxVestableAmount(true);
        vester.setHandler(HANDLER, true);
        vm.startPrank(HANDLER);
        vester.setTransferredCumulativeRewards(USER1, transferredCumulativeRewards);
        vester.setBonusRewards(USER1, bonusRewards);
        vm.startPrank(USER1);
            rewardTracker.approve(address(vester), sumRewards);
            vester.deposit(sumRewards);
        vm.stopPrank();
        assertEq(vester.balanceOf(USER1), sumRewards);
        uint256 vesterStakedBalance = zfiToken.balanceOf(address(vester));
        assertEq(sumRewards, vesterStakedBalance);
        uint256 vesterStakedAmount = rewardTracker.stakedAmounts(address(USER1));
        assertEq(0, vesterStakedAmount);
        vm.warp(block.timestamp + 1 days);
        uint256 claimableAmount = vester.claimable(USER1);
        assertEq(sumRewards / 7, claimableAmount);
        vm.startPrank(USER1);
            vester.claim();
        vm.stopPrank();
        uint256 vesterBalance = vester.balanceOf(USER1);
        assertEq(sumRewards - sumRewards / 7, vesterBalance);
        uint256 claimedBalance = zfiToken.balanceOf(USER1);
        assertEq(sumRewards / 7, claimedBalance);
        // 2nd day
        vm.warp(block.timestamp + 1 days);
        claimableAmount = vester.claimable(USER1);
        assertEq(sumRewards / 7, claimableAmount);
        vm.startPrank(USER1);
            vester.claim();
        vm.stopPrank();
        vesterBalance = vester.balanceOf(USER1);
        assertEq(sumRewards - sumRewards / 7 * 2, vesterBalance);
        claimedBalance = zfiToken.balanceOf(USER1);
        assertEq(sumRewards / 7 * 2, claimedBalance);
        // 3rd day
        vm.warp(block.timestamp + 1 days);
        claimableAmount = vester.claimable(USER1);
        assertEq(sumRewards / 7, claimableAmount);
        vm.startPrank(USER1);
            vester.claim();
        vm.stopPrank();
        vesterBalance = vester.balanceOf(USER1);
        assertEq(sumRewards - sumRewards / 7 * 3, vesterBalance);
        claimedBalance = zfiToken.balanceOf(USER1);
        assertEq(sumRewards / 7 * 3, claimedBalance);
        // 4th day
        vm.warp(block.timestamp + 1 days);
        claimableAmount = vester.claimable(USER1);
        assertEq(sumRewards / 7, claimableAmount);
        vm.startPrank(USER1);
            vester.claim();
        vm.stopPrank();
        vesterBalance = vester.balanceOf(USER1);
        assertEq(sumRewards - sumRewards / 7 * 4, vesterBalance);
        claimedBalance = zfiToken.balanceOf(USER1);
        assertEq(sumRewards / 7 * 4, claimedBalance);
        // 5th day
        vm.warp(block.timestamp + 1 days);
        claimableAmount = vester.claimable(USER1);
        assertEq(sumRewards / 7, claimableAmount);
        vm.startPrank(USER1);
            vester.claim();
        vm.stopPrank();
        vesterBalance = vester.balanceOf(USER1);
        assertEq(sumRewards - sumRewards / 7 * 5, vesterBalance);
        claimedBalance = zfiToken.balanceOf(USER1);
        assertEq(sumRewards / 7 * 5, claimedBalance);
        // 6th day
        vm.warp(block.timestamp + 1 days);
        claimableAmount = vester.claimable(USER1);
        assertEq(sumRewards / 7, claimableAmount);
        vm.startPrank(USER1);
            vester.claim();
        vm.stopPrank();
        vesterBalance = vester.balanceOf(USER1);
        assertEq(sumRewards - sumRewards / 7 * 6, vesterBalance);
        claimedBalance = zfiToken.balanceOf(USER1);
        assertEq(sumRewards / 7 * 6, claimedBalance);
        // 7th day
        vm.warp(block.timestamp + 1 days);
        claimableAmount = vester.claimable(USER1);
        assertEq(sumRewards / 7, claimableAmount);
        vm.startPrank(USER1);
            vester.claim();
        vm.stopPrank();
        vesterBalance = vester.balanceOf(USER1);
        assertEq(sumRewards - sumRewards, vesterBalance);
        claimedBalance = zfiToken.balanceOf(USER1);
        assertEq(sumRewards, claimedBalance);
        // 8th day (nothing to claim)
        vm.warp(block.timestamp + 1 days);
        claimableAmount = vester.claimable(USER1);
        assertEq(0, claimableAmount);
        vm.startPrank(USER1);
            vester.claim();
        vm.stopPrank();
        vesterBalance = vester.balanceOf(USER1);
        assertEq(0, vesterBalance);
        claimedBalance = zfiToken.balanceOf(USER1);
        assertEq(sumRewards, claimedBalance);
    }

    //TODO: getTotalVested (interesting)

    //TODO: getMaxVestableAmount

    //TODO: setBonusRewards

    //TODO: setCumulativeRewardDeductions

    //TODO: setTransferredCumulativeRewards

    //TODO: transferStakeValues

    //TODO: rescueFunds

    //TODO: claimForAccount (interesting)

    //TODO: setHasMaxVestableAmount
}
