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

    // deposit in Vester and claim after 2, 3 and 6 months
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

    function testMultipleDepositsAndClaims() public setGov(TEAM_ADDRESS){
        uint256 firstDeposit = 100 ether;
        uint256 secondDeposit = 100 ether;

        vm.prank(vester.gov());
        vester.setHasMaxVestableAmount(false);

        deal(address(zfiToken), USER1, firstDeposit+secondDeposit);
        // deposit in rewardTracker
        vm.startPrank(USER1);
        zfiToken.approve(address(rewardTracker), firstDeposit+secondDeposit);
        rewardTracker.stake(firstDeposit+secondDeposit);

        // USER deposits 100 tokens in the Vester
        vm.startPrank(USER1);
            rewardTracker.approve(address(vester), firstDeposit);
            vester.deposit(firstDeposit);
        vm.stopPrank();
        assertEq(vester.balanceOf(USER1), firstDeposit);

        // Wait for half a week
        vm.warp(block.timestamp + vestingDuration / 2);

        // Check claimable amount
        uint256 claimable = vester.claimable(USER1);
        assertApproxEqRel(claimable, firstDeposit / 2, 1e16); // Allow small precision error

        // Claim the vested tokens
        vm.startPrank(USER1);
        vester.claim();
        vm.stopPrank();
        assertEq(zfiToken.balanceOf(USER1), claimable);

        // Deposit another 100 tokens
        vm.startPrank(USER1);
        rewardTracker.approve(address(vester), secondDeposit);
        vester.deposit(secondDeposit);
        vm.stopPrank();
        assertEq(vester.balanceOf(USER1), firstDeposit + secondDeposit - claimable);

        // Wait for another half week
        vm.warp(block.timestamp + vestingDuration / 2);

        // Check claimable amount again
        claimable = vester.claimable(USER1);
        uint256 expectedClaimable = (firstDeposit + secondDeposit) / 2;
        assertApproxEqRel(claimable, expectedClaimable, 1e16);

        // Claim the vested tokens
        vm.startPrank(USER1);
        vester.claim();
        vm.stopPrank();
        assertEq(zfiToken.balanceOf(USER1), claimable + firstDeposit / 2);

        // Wait for another half week
        vm.warp(block.timestamp + vestingDuration / 2);

        // Check claimable amount again
        console2.log("I'm here");
        claimable = vester.claimable(USER1);
        assertApproxEqRel(claimable, secondDeposit / 2, 1e16);

        // Claim the remaining tokens
        vm.startPrank(USER1);
        vester.claim();
        vm.stopPrank();
        assertEq(zfiToken.balanceOf(USER1), firstDeposit + secondDeposit);

        // Ensure no further tokens can be claimed
        claimable = vester.claimable(USER1);
        assertEq(claimable, 0);
    }

    function test_withdraw() public setGov(TEAM_ADDRESS) {
    uint256 depositAmount = 100 ether;
    
    // Setup: Give user tokens and stake them
    deal(address(zfiToken), USER1, depositAmount);
    vm.startPrank(USER1);
    zfiToken.approve(address(rewardTracker), depositAmount);
    rewardTracker.stake(depositAmount);
    vm.stopPrank();
    
    // Disable max vestable amount for simplicity
    vm.prank(TEAM_ADDRESS);
    vester.setHasMaxVestableAmount(false);
    
    // User deposits into vester
    vm.startPrank(USER1);
    rewardTracker.approve(address(vester), depositAmount);
    vester.deposit(depositAmount);
    vm.stopPrank();
    
    // Verify initial state
    assertEq(vester.balanceOf(USER1), depositAmount);
    assertEq(vester.cumulativeClaimAmounts(USER1), 0);
    
    // Wait for partial vesting (half the duration)
    vm.warp(block.timestamp + vestingDuration / 2);
    
    // Claim some tokens first to test withdraw with mixed state
    vm.startPrank(USER1);
    uint256 claimedAmount = vester.claim();
    vm.stopPrank();
    
    // Verify partial claim
    uint256 expectedClaimedAmount = depositAmount / 2; // Half vested
    assertApproxEqRel(claimedAmount, expectedClaimedAmount, 1e16); // 1% tolerance
    assertEq(zfiToken.balanceOf(USER1), claimedAmount);
    assertEq(vester.cumulativeClaimAmounts(USER1), claimedAmount);
    
    // Record state before withdraw
    uint256 remainingBalance = vester.balanceOf(USER1);
    uint256 cumulativeClaimed = vester.cumulativeClaimAmounts(USER1);
    uint256 userZfiBalanceBefore = zfiToken.balanceOf(USER1);
    uint256 userStakedAmountBefore = rewardTracker.stakedAmounts(USER1);
    
    // Perform withdraw
    vm.startPrank(USER1);
    vester.withdraw();
    vm.stopPrank();
    
    // Verify withdraw effects
    // 1. Vester balance should be zero
    assertEq(vester.balanceOf(USER1), 0);
    
    // 2. Cumulative claim amounts should be reset
    assertEq(vester.cumulativeClaimAmounts(USER1), 0);
    
    // 3. Claimed amounts should be reset
    assertEq(vester.claimedAmounts(USER1), 0);
    
    // 4. Last vesting times should be reset
    assertEq(vester.lastVestingTimes(USER1), 0);
    
    // 5. User should receive additional claimable tokens in their wallet
    uint256 additionalClaimed = vester.claimable(USER1); // This should be 0 after withdraw
    assertEq(additionalClaimed, 0);
    
    // 6. User's ZFI balance should increase by any remaining claimable amount
    // Note: withdraw() calls _claim internally before staking
    uint256 userZfiBalanceAfter = zfiToken.balanceOf(USER1);
    assertTrue(userZfiBalanceAfter >= userZfiBalanceBefore);
    
    // 7. Remaining balance should be staked in reward tracker
    uint256 userStakedAmountAfter = rewardTracker.stakedAmounts(USER1);
    assertEq(userStakedAmountAfter, userStakedAmountBefore + remainingBalance);
}

function test_withdraw_FullyVested() public setGov(TEAM_ADDRESS) {
    uint256 depositAmount = 50 ether;
    
    // Setup
    deal(address(zfiToken), USER1, depositAmount);
    vm.startPrank(USER1);
    zfiToken.approve(address(rewardTracker), depositAmount);
    rewardTracker.stake(depositAmount);
    vm.stopPrank();
    
    vm.prank(TEAM_ADDRESS);
    vester.setHasMaxVestableAmount(false);
    
    // Deposit
    vm.startPrank(USER1);
    rewardTracker.approve(address(vester), depositAmount);
    vester.deposit(depositAmount);
    vm.stopPrank();
    
    // Wait for full vesting
    vm.warp(block.timestamp + vestingDuration + 1);
    
    uint256 userStakedBefore = rewardTracker.stakedAmounts(USER1);
    console2.log("userStakedBefore");
    console2.log(userStakedBefore);
    uint256 claimableBefore = vester.claimable(USER1);
    assertEq(claimableBefore, depositAmount); // Fully claimable
    
    // Withdraw
    vm.startPrank(USER1);
    vester.claim();
    vm.expectRevert();
    vester.withdraw();
    vm.stopPrank();
    
    // Verify all tokens were claimed and none restaked (since balance was 0)
    assertEq(zfiToken.balanceOf(USER1), depositAmount);
    assertEq(rewardTracker.stakedAmounts(USER1), userStakedBefore); // No change in staking
    assertEq(vester.balanceOf(USER1), 0);
}

function test_withdraw_NoVestedAmount_ShouldRevert() public setGov(TEAM_ADDRESS) {
    // Try to withdraw without any deposit
    vm.startPrank(USER1);
    vm.expectRevert("Vester: vested amount is zero");
    vester.withdraw();
    vm.stopPrank();
}

function test_withdraw_OnlyUnvestedBalance() public setGov(TEAM_ADDRESS) {
    uint256 depositAmount = 80 ether;
    
    // Setup
    deal(address(zfiToken), USER1, depositAmount);
    vm.startPrank(USER1);
    zfiToken.approve(address(rewardTracker), depositAmount);
    rewardTracker.stake(depositAmount);
    vm.stopPrank();
    
    vm.prank(TEAM_ADDRESS);
    vester.setHasMaxVestableAmount(false);
    
    // Deposit
    vm.startPrank(USER1);
    rewardTracker.approve(address(vester), depositAmount);
    vester.deposit(depositAmount);
    vm.stopPrank();
    
    // Withdraw immediately (no vesting time passed)
    uint256 userStakedBefore = rewardTracker.stakedAmounts(USER1);
    
    vm.startPrank(USER1);
    vester.withdraw();
    vm.stopPrank();
    
    // Should have no ZFI tokens (nothing was claimable)
    assertEq(zfiToken.balanceOf(USER1), 0);
    
    // All deposited amount should be restaked
    assertEq(rewardTracker.stakedAmounts(USER1), userStakedBefore + depositAmount);
    
    // Vester state should be cleared
    assertEq(vester.balanceOf(USER1), 0);
    assertEq(vester.cumulativeClaimAmounts(USER1), 0);
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
