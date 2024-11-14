// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ZFIToken} from "../src/ZFI/ZFIToken.sol";

contract ZfiScript is Script {
    address ADMIN_ADDRESS;
    address PROXY;

    function setUp() public {
        ADMIN_ADDRESS = vm.envAddress("ADMIN_ADDRESS");
    }

    function run() public {
        vm.startBroadcast();
        address ZFITokenImplementation = address(new ZFIToken());
        PROXY = address(new ERC1967Proxy(ZFITokenImplementation, abi.encodeCall(ZFIToken.initialize2, (ADMIN_ADDRESS))));
        console2.log("Token address is: ");
        console2.log(PROXY);

        mintToken(ADMIN_ADDRESS, 1 ether);
        vm.stopBroadcast();
    }

    function mintToken(address _to, uint256 _amount) internal {
        ZFIToken token = ZFIToken(PROXY);
        token.mint(_to, _amount);
    }
}