// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ZFIToken} from "../src/ZFI/ZFIToken.sol";

contract ZFI_test is Test {
    address TEAM_ADDRESS = makeAddr("TEAM_ADDRESS");
    address DEPLOYER_ADDRESS = makeAddr("DEPLOYER_ADDRESS");
    address USER1 = makeAddr("USER1");
    ZFIToken zfiToken;

    function setUp() public {
        deal(DEPLOYER_ADDRESS, 2 ether);
        vm.startPrank(DEPLOYER_ADDRESS);

        //TODO: fix the deployement via openzeppelin Upgrades
        // address proxy = Upgrades.deployUUPSProxy(
        // "ZFIToken.sol",
        // abi.encodeCall(ZFIToken.initialize2, (TEAM_ADDRESS)));

        // In the meantime, unsafe deployment:
        zfiToken = ZFIToken(deploy_ZFI());
        vm.stopPrank();
    }

    function deploy_ZFI() public returns(address ZFY_proxy_address){
        address ZFITokenImplementation = address(new ZFIToken());
        ZFY_proxy_address = address(new ERC1967Proxy(ZFITokenImplementation, abi.encodeCall(ZFIToken.initialize2, (TEAM_ADDRESS))));
    }

    function test_GiveAdminRoleAway() public {
        vm.startPrank(DEPLOYER_ADDRESS);
        zfiToken.grantRole(zfiToken.DEFAULT_ADMIN_ROLE(), TEAM_ADDRESS);
        vm.stopPrank();
        vm.deal(TEAM_ADDRESS, 2 ether);
        vm.startPrank(TEAM_ADDRESS);
        zfiToken.revokeRole(zfiToken.DEFAULT_ADMIN_ROLE(), DEPLOYER_ADDRESS);
        vm.stopPrank();
        assertTrue(zfiToken.hasRole(zfiToken.DEFAULT_ADMIN_ROLE(), TEAM_ADDRESS));
    }

    function test_Mint() public {
        test_GiveAdminRoleAway();
        vm.startPrank(DEPLOYER_ADDRESS);
        zfiToken.mint(USER1, 10 ether);
        vm.stopPrank();
        assertTrue(zfiToken.balanceOf(USER1) == 10 ether);
    }

    function test_Pause() public {
        test_GiveAdminRoleAway();
        vm.startPrank(DEPLOYER_ADDRESS);
        zfiToken.mint(USER1, 10 ether);
        zfiToken.pause();
        vm.stopPrank();
        vm.startPrank(USER1);
        vm.expectRevert();
        zfiToken.transfer(DEPLOYER_ADDRESS, 10 ether);
    }

    function test_Upgrade() public {
        address newImplem =  address(new ZFIToken());
        bytes memory data = "";
        zfiToken.upgradeToAndCall(newImplem, data);
    }
}
