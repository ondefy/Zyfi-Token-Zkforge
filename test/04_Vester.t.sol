// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {ZYFI_test, ZYFIToken} from "./00_ZYFI.t.sol";
import {Vester} from "src/staking/Vester.sol";
import {RewardTracker_Tester, RewardTracker, RewardDistributor} from "./02_RewardTracker.t.sol";

contract Vester_Tester is Test {
    address TEAM_ADDRESS = makeAddr("TEAM_ADDRESS");
    address DEPLOYER_ADDRESS = makeAddr("DEPLOYER_ADDRESS");
    address USER1 = makeAddr("USER1");
    address HANDLER = makeAddr("HANDLER");
    ZYFIToken zyfiToken;
    RewardTracker rewardTracker;
    ZYFI_test zifyDeployer = new ZYFI_test();
    address[] depositTokens;
    RewardTracker_Tester rewardTrackerDeployer = new RewardTracker_Tester();
    Vester vester;
    address DISTRIBUTOR;

    function setUp() public {
        deal(DEPLOYER_ADDRESS, 2 ether);
        deal(TEAM_ADDRESS, 2 ether);
        deal(USER1, 2 ether);

        vm.startPrank(DEPLOYER_ADDRESS);
        // Deploy ZYFI:
        address zyfiTokenAddress = zifyDeployer.deploy_ZYFI();
        zyfiToken = ZYFIToken(zyfiTokenAddress);

        //deploy RewardTracker:
        rewardTracker = RewardTracker(rewardTrackerDeployer.deployRewardTracker());
        
        console2.log("The address governing the vestrewardTrackerer is: ");
        console2.log(rewardTracker.gov());
        vm.stopPrank();

        vm.prank(DEPLOYER_ADDRESS);
        rewardTracker.setGov(TEAM_ADDRESS);

        // Enable deposit of stZFI
        depositTokens.push(address(rewardTracker));
        DISTRIBUTOR = deployRewardDistributor();

        vm.prank(TEAM_ADDRESS);
        rewardTracker.initialize(depositTokens, DISTRIBUTOR);     

        uint256 vestingDuration = 4 * 6 weeks; // 26 weeks = 6 months
        vm.prank(DEPLOYER_ADDRESS);
        vester = new Vester("staked ZFI", "stZFI", vestingDuration, address(rewardTracker), zyfiTokenAddress, address(rewardTracker));
        vm.stopPrank();
    }

    function deployRewardDistributor() public returns(address rewardDistributorAddress){
        vm.startPrank(DEPLOYER_ADDRESS);
        rewardDistributorAddress = address(new RewardDistributor(address(zyfiToken), address(rewardTracker)));
        console2.log(rewardDistributorAddress);
        vm.stopPrank();
    }

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
        deal(address(rewardTracker), USER1, 2 ether);
        console2.log(vester.gov());
        vm.prank(TEAM_ADDRESS);
        vester.setHasMaxVestableAmount(false);

        vm.startPrank(USER1);
            rewardTracker.approve(address(vester), 2 ether);
            vester.deposit(2 ether);
        vm.stopPrank();
        assertEq(vester.balanceOf(USER1), 2 ether); 
    }

    function test_deposit_MaxVestableAmount() public setGov(TEAM_ADDRESS){
        uint256 transferredCumulativeRewards = 10 ether;
        uint256 bonusRewards = 15 ether;
        uint256 sumRewards = transferredCumulativeRewards + bonusRewards;
        deal(address(rewardTracker), USER1, sumRewards);
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

    //TODO: deposit in Vester and claim after 6 months

}
