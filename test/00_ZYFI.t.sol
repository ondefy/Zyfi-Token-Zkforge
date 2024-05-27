// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ZYFIToken} from "../src/zyfi/ZYFIToken.sol";

contract ZYFI_test is Test {
    address TEAM_ADDRESS = makeAddr("TEAM_ADDRESS");
    address DEPLOYER_ADDRESS = makeAddr("DEPLOYER_ADDRESS");
    address USER1 = makeAddr("USER1");
    ZYFIToken zyfiToken;

    function setUp() public {
        deal(DEPLOYER_ADDRESS, 2 ether);
        vm.startPrank(DEPLOYER_ADDRESS);

        //TODO: fix the deployement via openzeppelin Upgrades
        // address proxy = Upgrades.deployUUPSProxy(
        // "ZYFIToken.sol",
        // abi.encodeCall(ZYFIToken.initialize2, (TEAM_ADDRESS)));

        // In the meantime, unsafe deployment:
        zyfiToken = ZYFIToken(deploy_ZYFI());
        vm.stopPrank();
    }

    function deploy_ZYFI() public returns(address ZFY_proxy_address){
        address ZYFITokenImplementation = address(new ZYFIToken());
        ZFY_proxy_address = address(new ERC1967Proxy(ZYFITokenImplementation, abi.encodeCall(ZYFIToken.initialize2, (TEAM_ADDRESS))));
    }

    function test_GiveAdminRoleAway() public {
        vm.startPrank(DEPLOYER_ADDRESS);
        zyfiToken.grantRole(zyfiToken.DEFAULT_ADMIN_ROLE(), TEAM_ADDRESS);
        vm.stopPrank();
        vm.deal(TEAM_ADDRESS, 2 ether);
        vm.startPrank(TEAM_ADDRESS);
        zyfiToken.revokeRole(zyfiToken.DEFAULT_ADMIN_ROLE(), DEPLOYER_ADDRESS);
        vm.stopPrank();
        //TODO: add the checks
    }

    function test_Mint() public {
        test_GiveAdminRoleAway();
        //TODO
    }

    function test_Pause() public {
        //TODO
    }

    function test_Upgrade() public {
        //TODO
    }


//     function testFuzz_SetNumber(uint256 x) public {
//         counter.setNumber(x);
//         assertEq(counter.number(), x);
//     }
}
