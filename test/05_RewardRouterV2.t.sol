// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {ZFI_test, ZFIToken} from "./00_ZFI.t.sol";

contract RewardRouter is Test {
    address TEAM_ADDRESS;
    address DEPLOYER_ADDRESS;
    ZFIToken zfiToken;
    //RewardRouterV2 rewardRouter;

    function setUp() public {
        TEAM_ADDRESS = makeAddr("TEAM_ADDRESS");
        DEPLOYER_ADDRESS = makeAddr("DEPLOYER_ADDRESS");
        deal(DEPLOYER_ADDRESS, 2 ether);
        vm.startPrank(DEPLOYER_ADDRESS);

        // rewardRouter = new RewardRouterV2();
        // rewardRouter.initialize(address(ZFIToken), address(esZfyToken));     
        vm.stopPrank();
    }


}
