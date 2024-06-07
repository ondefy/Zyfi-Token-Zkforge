// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {ZYFI_test, ZYFIToken} from "./00_ZYFI.t.sol";
import {esZYFI_test, esZYFIToken} from "./01_esZYFI.t.sol";
import {Vester} from "src/staking/Vester.sol";
import {RewardTracker_Tester, RewardTracker} from "./02_RewardTracker.t.sol";

contract Vester_Tester is Test {
    address TEAM_ADDRESS = makeAddr("TEAM_ADDRESS");
    address DEPLOYER_ADDRESS = makeAddr("DEPLOYER_ADDRESS");
    address USER1 = makeAddr("USER1");
    address USER2 = makeAddr("USER2");
    address USER3 = makeAddr("USER3");

    ZYFIToken zyfiToken;
    esZYFIToken esZyfiToken;
    RewardTracker rewardTracker;

    ZYFI_test zifyDeployer = new ZYFI_test();
    esZYFI_test esZifyDeployer = new esZYFI_test();

    address[] depositTokens;
    RewardTracker_Tester rewardTrackerDeployer = new RewardTracker_Tester();

    Vester vester;

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

        //deploy RewardTracker:
        rewardTracker = RewardTracker(rewardTrackerDeployer.deployRewardTracker());
        
        console2.log("The address governing the vestrewardTrackerer is: ");
        console2.log(rewardTracker.gov());
        vm.stopPrank();

        vm.prank(DEPLOYER_ADDRESS);
        rewardTracker.setGov(TEAM_ADDRESS);

        depositTokens.push(zyfiTokenAddress);
        vm.prank(TEAM_ADDRESS);
        rewardTracker.initialize(depositTokens, makeAddr("DISTRIBUTOR"));     

        uint256 vestingDuration = 4 * 6 weeks; // 26 weeks = 6 months
        vm.prank(DEPLOYER_ADDRESS);
        vester = new Vester("vestedZIFY", "vZYFI", vestingDuration, esZyfiTokenAddress, zyfiTokenAddress, address(rewardTracker));
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
        deal(address(esZyfiToken), USER1, 2 ether);
        console2.log(vester.gov());
        vm.prank(TEAM_ADDRESS);
        vester.setHasMaxVestableAmount(false);

        vm.startPrank(USER1);
        esZyfiToken.approve(address(vester), 2 ether);
        vester.deposit(2 ether);
        vm.stopPrank();
        assertEq(vester.balanceOf(USER1), 2 ether); 
    }

    function test_deposit_MaxVestableAmount(uint256 transferredCumulativeRewards, uint256 cumulativeRewardDeductions, uint256 bonusRewards) public setGov(TEAM_ADDRESS){
        // uint256 sumRewards = transferredCumulativeRewards + /* cumulativeClaimAmounts + */ bonusRewards;
        // deal(address(esZyfiToken), USER1, sumRewards);
        // vm.startPrank(TEAM_ADDRESS);
        // vester.setHasMaxVestableAmount(true);
        // vester.setHandler(TEAM_ADDRESS, true);
        // vester.setTransferredCumulativeRewards(USER1, transferredCumulativeRewards);
        // vester.setCumulativeRewardDeductions(USER1, cumulativeRewardDeductions);
        // vester.setBonusRewards(USER1, bonusRewards);
        // vm.stopPrank();
        // vm.startPrank(USER1);
        // esZyfiToken.approve(address(vester), 2 ether);
        // vester.deposit(sumRewards);
        // vm.stopPrank();
        // assertEq(vester.balanceOf(USER1), 2 ether); 
    }

    function test_transfer_whitelist() public setGov(TEAM_ADDRESS) {
        uint256 amount = 1 ether;
        // mint to user1
        deal(address(esZyfiToken), USER1, amount);
        // disable max vestable amount
        vm.prank(TEAM_ADDRESS);
        vester.setHasMaxVestableAmount(false);
        // user1 deposits into vesting contract
        vm.startPrank(USER1);
        esZyfiToken.approve(address(vester), amount);
        vester.deposit(amount);
        // user1 tries to transfer, expect revert
        vm.expectRevert();
        vester.transfer(USER2, amount);
        vm.stopPrank();
        // whitelist user1
        vm.prank(TEAM_ADDRESS);
        vester.setIsWhitelistedSender(USER1, true);
        vm.startPrank(USER1);
        // user1 tries to transfer again, expect success
        vester.transfer(USER2, amount);
        vm.stopPrank();
        assertEq(vester.balanceOf(USER1), 0); 
        assertEq(vester.balanceOf(USER2), amount); 
    }
    
    function test_transferfrom_whitelist() public setGov(TEAM_ADDRESS) {
        // disable max vestable amount & whitelist user1
        vm.startPrank(TEAM_ADDRESS);
        vester.setHasMaxVestableAmount(false);
        vester.setIsWhitelistedSender(USER1, true);
        vm.stopPrank();
        // mint to user1
        uint256 amount = 1 ether;
        deal(address(esZyfiToken), USER1, amount);
        // user1 deposits into vesting contract
        vm.startPrank(USER1);
        esZyfiToken.approve(address(vester), amount);
        vester.deposit(amount);
        // user1 approves user2
        vester.approve(USER2, amount);
        vm.stopPrank();
        // user2 tries to transfer user1's funds, expect revert
        vm.prank(USER2);
        vm.expectRevert();
        vester.transferFrom(USER1, USER3, amount);
        // user2 gets whitelisted for transfers
        vm.prank(TEAM_ADDRESS);
        vester.setIsWhitelistedSender(USER2, true);
        // user2 tries to transfer user1's funds again, expect success
        vm.prank(USER2);
        vester.transferFrom(USER1, USER3, amount);
        assertEq(vester.balanceOf(USER1), 0); 
        assertEq(vester.balanceOf(USER2), 0); 
        assertEq(vester.balanceOf(USER3), amount); 
    }
}
