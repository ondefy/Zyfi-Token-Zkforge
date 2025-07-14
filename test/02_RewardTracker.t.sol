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
        rewardTrackerAddress = address(new RewardTracker("staked ZFI", "stZFI", zfiTokenAddress));
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

    function test_stake() public setGov(TEAM_ADDRESS) returns (address user, uint256 amount){
        amount = 1000 ether;
        deal(address(zfiToken), USER1, amount);
        // setDepositToken
        // vm.startPrank(TEAM_ADDRESS);
        // rewardTracker.setDepositToken(address(zfiToken), true);
        // vm.stopPrank();

        vm.startPrank(USER1);
            zfiToken.approve(address(rewardTracker), amount);
            rewardTracker.stake(amount);
        vm.stopPrank();
        uint256 balance = rewardTracker.balanceOf(USER1);
        assertEq(balance, amount);
        return (USER1, amount);
    }

    //TODO: test privateTransferMode so stZFI isn't transferable but for handlers
    function test_privateTransferMode() public {
        (address user, uint256 amount) = test_stake();
        address handler = makeAddr("handler");
        vm.startPrank(TEAM_ADDRESS);
        rewardTracker.setHandler(handler, true);
        rewardTracker.setPrivateMode(RewardTracker.Mode.Transfer, true);
        assertEq(zfiToken.balanceOf(user), 0);
        vm.startPrank(user);
        vm.expectRevert();
        rewardTracker.transfer(address(0x1), amount);
        uint256 handlerAmount = 1 ether;
        vm.startPrank(handler);
        deal(address(zfiToken), handler, handlerAmount);
        zfiToken.approve(address(rewardTracker), handlerAmount);
        rewardTracker.stake(handlerAmount);
        assertEq(rewardTracker.balanceOf(handler), handlerAmount);
        rewardTracker.transfer(address(0x1), handlerAmount);
        assertEq(rewardTracker.balanceOf(handler), 0);
        assertEq(rewardTracker.balanceOf(address(0x1)), handlerAmount);
    }

    //TODO: test more integration (boost: setRewardBoost + rewards via stake)

    // batchSetRewardBoost
    function test_batchSetRewardBoost() public setGov(TEAM_ADDRESS) {
        address[] memory accounts = new address[](3);
        accounts[0] = address(0x1);
        accounts[1] = address(0x2);
        accounts[2] = address(0x3);
        uint256[] memory boostBasisPoints = new uint256[](3);
        boostBasisPoints[0] = 5_000;
        boostBasisPoints[1] = 10_000;
        boostBasisPoints[2] = 10_000;
        vm.startPrank(TEAM_ADDRESS);
        rewardTracker.batchSetRewardBoost(accounts, boostBasisPoints);
        assertEq(rewardTracker.rewardBoostsBasisPoints(address(0x1)), 5_000);
        assertEq(rewardTracker.rewardBoostsBasisPoints(address(0x2)), 10_000);
        assertEq(rewardTracker.rewardBoostsBasisPoints(address(0x3)), 10_000);
    }

    function test_batchSetRewardBoostTooHigh() public setGov(TEAM_ADDRESS) {
        address handler = makeAddr("handler");
        address[] memory accounts = new address[](3);
        accounts[0] = address(0x1);
        accounts[1] = address(0x2);
        accounts[2] = address(0x3);
        uint256[] memory boostBasisPoints = new uint256[](3);
        boostBasisPoints[0] = 5_000;
        boostBasisPoints[1] = 10_000;
        boostBasisPoints[2] = 20_000;
        vm.startPrank(TEAM_ADDRESS);
        vm.expectRevert();
        rewardTracker.batchSetRewardBoost(accounts, boostBasisPoints);
        assertEq(rewardTracker.rewardBoostsBasisPoints(address(0x1)), 0);
        assertEq(rewardTracker.rewardBoostsBasisPoints(address(0x2)), 0);
        assertEq(rewardTracker.rewardBoostsBasisPoints(address(0x3)), 0);
    }

    // setHandler
    function test_setHandler() public setGov(TEAM_ADDRESS) {
        address handler = makeAddr("handler");
        vm.startPrank(TEAM_ADDRESS);
        rewardTracker.setHandler(handler, true);
        assertEq(rewardTracker.isHandler(handler), true);
        rewardTracker.setHandler(handler, false);
        assertEq(rewardTracker.isHandler(handler), false);
    }

    // setInPrivateClaimingMode
    function test_privateClaimingMode() public setGov(TEAM_ADDRESS) {
        uint256 amount = 1 ether;
        address handler = makeAddr("handler");
        vm.startPrank(TEAM_ADDRESS);
        rewardTracker.setHandler(handler, true);
        rewardTracker.setPrivateMode(RewardTracker.Mode.Claiming, true);
        assertEq(zfiToken.balanceOf(USER1), 0);
        vm.startPrank(USER1);
        deal(address(zfiToken), USER1, amount);
        zfiToken.approve(address(rewardTracker), amount);
        rewardTracker.stake(amount);
        assertEq(rewardTracker.balanceOf(USER1), amount);
        vm.expectRevert();
        rewardTracker.claim(USER1);
        vm.startPrank(handler);
        deal(address(zfiToken), handler, amount);
        zfiToken.approve(address(rewardTracker), amount);
        rewardTracker.stake(amount);
        assertEq(rewardTracker.balanceOf(handler), amount);
        rewardTracker.claimForAccount(handler, handler);
        rewardTracker.claimForAccount(USER1, USER1);
    }

    // setInPrivateStakingMode
    function test_privateStakingMode() public setGov(TEAM_ADDRESS) {
        address handler = makeAddr("handler");
        vm.startPrank(TEAM_ADDRESS);
        rewardTracker.setHandler(handler, true);
        rewardTracker.setPrivateMode(RewardTracker.Mode.Staking, true);
        assertEq(zfiToken.balanceOf(USER1), 0);
        vm.startPrank(USER1);
        deal(address(zfiToken), USER1, 1 ether);
        zfiToken.approve(address(rewardTracker), 1 ether);
        vm.expectRevert();
        rewardTracker.stake(1 ether);
        vm.startPrank(handler);
        deal(address(zfiToken), handler, 1 ether);
        rewardTracker.stakeForAccount(USER1, USER1, 1 ether);
        assertEq(rewardTracker.balanceOf(USER1), 1 ether);
    }

    // getVotes + self delegate
    function test_getVotes() public setGov(TEAM_ADDRESS) {
        uint256 amount = 10_000 ether;
        assertEq(rewardTracker.getVotes(USER1), 0);
        deal(address(zfiToken), USER1, amount);
        vm.startPrank(USER1);
        rewardTracker.delegate(USER1);
        zfiToken.approve(address(rewardTracker), amount);
        rewardTracker.stake(amount);
        vm.warp(block.timestamp + 1 days);
        assertEq(rewardTracker.getVotes(USER1), amount);
        assertEq(rewardTracker.delegates(USER1), USER1);
        address handler = makeAddr("handler");
        vm.startPrank(TEAM_ADDRESS);
        rewardTracker.setHandler(handler, true);
        vm.startPrank(handler);
        // unstake user's ZFI
        rewardTracker.unstakeForAccount(USER1, amount, USER1);
        //check if user's votes are 0
        assertEq(rewardTracker.getVotes(USER1), 0);
    }

    // check that the votes are transfered after a transfer of stZFI
    function test_transfer() public setGov(TEAM_ADDRESS) {
        uint256 amount = 10_000 ether;
        deal(address(zfiToken), USER1, amount);
        vm.startPrank(USER1);
        rewardTracker.delegate(USER1);
        zfiToken.approve(address(rewardTracker), amount);
        rewardTracker.stake(amount);
        vm.warp(block.timestamp + 1 days);
        assertEq(rewardTracker.getVotes(USER1), amount);
        assertEq(rewardTracker.delegates(USER1), USER1);
        // transfer stZFI to handler
        address handler = makeAddr("handler");
        rewardTracker.transfer(handler, amount);
        vm.startPrank(handler);
        rewardTracker.delegate(handler);
        //check if handler's votes are equal to the amount
        assertEq(rewardTracker.getVotes(handler), amount);
        assertEq(rewardTracker.delegates(handler), handler);
    }

    // getPastVotes
    function test_getPastVotes() public {
        uint256 amount = 10_000 ether;
        deal(address(zfiToken), USER1, amount);
        vm.startPrank(USER1);
        rewardTracker.delegate(USER1);
        zfiToken.approve(address(rewardTracker), amount);
        rewardTracker.stake(amount);
        assertEq(rewardTracker.getVotes(USER1), amount);
        assertEq(rewardTracker.delegates(USER1), USER1);
        vm.warp(block.timestamp + 1 days);
        // transfer stZFI to handler
        address handler = makeAddr("handler");
        rewardTracker.transfer(handler, amount);
        vm.startPrank(handler);
        rewardTracker.delegate(handler);
        //check if handler's votes are equal to the amount
        assertEq(rewardTracker.getVotes(handler), amount);
        assertEq(rewardTracker.delegates(handler), handler);
        vm.warp(block.timestamp + 2 days);
        assertEq(rewardTracker.getPastVotes(USER1, block.timestamp - 2 days - 1), amount);
    }

    //TODO: getPastTotalSupply
    // stake as the user1 and 2 days later stake as the handler, then check the past total supply
    function test_getPastTotalSupply() public {
        uint256 amount = 10_000 ether;
        deal(address(zfiToken), USER1, amount);
        vm.startPrank(USER1);
        rewardTracker.delegate(USER1);
        zfiToken.approve(address(rewardTracker), amount);
        rewardTracker.stake(amount);
        assertEq(rewardTracker.getVotes(USER1), amount);
        assertEq(rewardTracker.delegates(USER1), USER1);
        vm.warp(block.timestamp + 1 days);
        // transfer stZFI to handler
        address handler = makeAddr("handler");
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(handler);
        // deal to handler
        deal(address(zfiToken), handler, amount);
        // stake as handler
        zfiToken.approve(address(rewardTracker), amount);
        rewardTracker.stake(amount);
        rewardTracker.delegate(handler);
        //check if handler's votes are equal to the amount
        assertEq(rewardTracker.getVotes(handler), amount);
        assertEq(rewardTracker.delegates(handler), handler);
        //get current total supply
        assertEq(rewardTracker.totalSupply(), amount * 2);
        assertEq(rewardTracker.getPastTotalSupply(block.timestamp - 1 days - 1), amount);
    }
}
