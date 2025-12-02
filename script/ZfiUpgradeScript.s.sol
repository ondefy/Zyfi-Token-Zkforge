// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ZFIToken} from "src/ZFI/ZFIToken.sol";
import {console} from "forge-std/console.sol";

contract ZfiUpgradeScript is Script {
    address proxy_address;
    address newImplementation;
    address GOV_ADDRESS;

    string internal newName = "ZyFAI";
    string internal newSymbol = "ZFI";

    function run() public {
        vm.startBroadcast();
        _upgrade();
        vm.stopBroadcast();
    }

    function _upgrade() internal {
        proxy_address = vm.envAddress("ZFI_TOKEN");
        GOV_ADDRESS = vm.envAddress("GOV_ADDRESS");

        newImplementation = address(new ZFIToken());
        console.log("New Zyfi token Implementation deployed at ", newImplementation);

        UUPSUpgradeable proxy_token = UUPSUpgradeable(proxy_address);

        //deploy new impl, call upgradeAndCall for the name update
        bytes memory _calldata = abi.encodeWithSelector(ZFIToken.updateNameAndSymbol.selector, newName, newSymbol);
        
        proxy_token.upgradeToAndCall(newImplementation, _calldata);
    }
}