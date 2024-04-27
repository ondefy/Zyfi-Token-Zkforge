// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ODYToken} from "../src/ody/ODYToken.sol";

contract ZFY is Test {
    address TEAM_ADDRESS;
    address DEPLOYER_ADDRESS;
    ODYToken public zfyToken;

    function setUp() public {
        TEAM_ADDRESS = makeAddr("TEAM_ADDRESS");
        DEPLOYER_ADDRESS = makeAddr("DEPLOYER_ADDRESS");
        deal(DEPLOYER_ADDRESS, 2 ether);
        vm.startPrank(DEPLOYER_ADDRESS);

        //TODO: fix the deployement via openzeppelin Upgrades
        // address proxy = Upgrades.deployUUPSProxy(
        // "ODYToken.sol",
        // abi.encodeCall(ODYToken.initialize2, (TEAM_ADDRESS)));

        // In the meantime, unsafe deployment:
        address ondefyTokenImplementation = address(new ODYToken());
        address proxy = address(new ERC1967Proxy(ondefyTokenImplementation, abi.encodeCall(ODYToken.initialize2, (TEAM_ADDRESS))));
        zfyToken = ODYToken(proxy);
        vm.stopPrank();
    }

function test_GiveAdminRoleAway() public {
    vm.startPrank(DEPLOYER_ADDRESS);
    zfyToken.grantRole(zfyToken.DEFAULT_ADMIN_ROLE(), TEAM_ADDRESS);
    vm.stopPrank();
    vm.deal(TEAM_ADDRESS, 2 ether);
    vm.startPrank(TEAM_ADDRESS);
    zfyToken.revokeRole(zfyToken.DEFAULT_ADMIN_ROLE(), DEPLOYER_ADDRESS);
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
