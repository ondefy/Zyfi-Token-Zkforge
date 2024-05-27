// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {esZYFIToken} from "../src/zyfi/esZYFIToken.sol";

contract esZYFI_test is Test {
    address TEAM_ADDRESS;
    address DEPLOYER_ADDRESS;
    esZYFIToken esZyfiToken;

    function setUp() public {
        TEAM_ADDRESS = makeAddr("TEAM_ADDRESS");
        DEPLOYER_ADDRESS = makeAddr("DEPLOYER_ADDRESS");
        deal(DEPLOYER_ADDRESS, 2 ether);
        vm.startPrank(DEPLOYER_ADDRESS);

        //TODO: fix the deployement via openzeppelin Upgrades
        // address proxy = Upgrades.deployUUPSProxy(
        // "esZFYToken.sol",
        // abi.encodeCall(esZFYToken.initialize2, (TEAM_ADDRESS)));

        // In the meantime, unsafe deployment:
        esZyfiToken = esZYFIToken(deploy_esZYFI());
        vm.stopPrank();
    }

    function deploy_esZYFI() public returns(address esZFY_proxy_address){
        address esZFYTokenImplementation = address(new esZYFIToken());
        esZFY_proxy_address = address(new ERC1967Proxy(esZFYTokenImplementation, abi.encodeCall(esZYFIToken.initialize2, (TEAM_ADDRESS))));
    }

    function test_GiveAdminRoleAway() public {
        vm.startPrank(DEPLOYER_ADDRESS);
        esZyfiToken.grantRole(esZyfiToken.DEFAULT_ADMIN_ROLE(), TEAM_ADDRESS);
        vm.stopPrank();
        vm.deal(TEAM_ADDRESS, 2 ether);
        vm.startPrank(TEAM_ADDRESS);
        esZyfiToken.revokeRole(esZyfiToken.DEFAULT_ADMIN_ROLE(), DEPLOYER_ADDRESS);
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
