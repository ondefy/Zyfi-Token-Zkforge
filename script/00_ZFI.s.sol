// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ZFIToken} from "../src/ZFI/ZFIToken.sol";

contract ZfiScript is Script {
    address GOV_ADDRESS;
    address PROXY;

    function setUp() public {}

    function run() public {
        
        vm.startBroadcast();
        GOV_ADDRESS = 0xea571612053f23471BAF7A573B6541eA54D9EE05;

        address ZFITokenImplementation = address(new ZFIToken());
        PROXY = address(new ERC1967Proxy(ZFITokenImplementation, abi.encodeCall(ZFIToken.initialize2, (GOV_ADDRESS))));
        console2.log("Token address is: ");
        console2.log(PROXY);
        //TODO: add mints here using (Merkledrop mint is in MerkleDrop script)
        // mintToken(GOV_ADDRESS, 1 ether);
        vm.stopBroadcast();
    }

    function mintToken(address _to, uint256 _amount) internal {
        ZFIToken token = ZFIToken(PROXY);
        token.mint(_to, _amount);
    }
}