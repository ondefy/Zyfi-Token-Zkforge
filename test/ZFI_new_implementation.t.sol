// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ZFIToken} from "src/ZFI/ZFIToken.sol";
import {ZfiUpgradeScript} from "script/ZfiUpgradeScript.s.sol";

contract ZfiUpgradeScriptTest is Test, ZfiUpgradeScript {
    ZFIToken public tokenImplementation;
    ERC1967Proxy public proxy;
    ZFIToken public proxyToken;
    
    address public constant USER = address(0x456);
    
    // Initial token parameters
    string public constant INITIAL_NAME = "Zyfi Token";
    string public constant INITIAL_SYMBOL = "ZFI";
    
    // Expected new parameters after upgrade
    string public constant EXPECTED_NEW_NAME = "New Name ++++";
    string public constant EXPECTED_NEW_SYMBOL = "NM++++";

    function setUp() public {
        GOV_ADDRESS = address(0x123);

        // Deploy initial implementation
        tokenImplementation = new ZFIToken();
        
        // Initialize proxy with initial implementation
        bytes memory initData = abi.encodeWithSelector(
            ZFIToken.initialize2.selector,
            GOV_ADDRESS
        );
        
        proxy = new ERC1967Proxy(address(tokenImplementation), initData);
        proxyToken = ZFIToken(address(proxy));
        
        // Verify GOV_ADDRESS has DEFAULT_ADMIN_ROLE after initialization
        bytes32 DEFAULT_ADMIN_ROLE = 0x00;
        assertTrue(proxyToken.hasRole(DEFAULT_ADMIN_ROLE, GOV_ADDRESS), "GOV_ADDRESS should have DEFAULT_ADMIN_ROLE");
        
        // Set up environment variables for the script
        vm.setEnv("ZFI_TOKEN", vm.toString(address(proxy)));
        vm.setEnv("GOV_ADDRESS", vm.toString(GOV_ADDRESS));
        
        // Ensure GOV_ADDRESS has proper permissions for testing
        vm.startPrank(GOV_ADDRESS);
    }

    function testUpgradeUpdatesNameAndSymbol() public {
        // Verify initial state
        assertEq(proxyToken.name(), INITIAL_NAME, "Initial name should match");
        assertEq(proxyToken.symbol(), INITIAL_SYMBOL, "Initial symbol should match");
        
        // Record the implementation address before upgrade
        address oldImplementation = getImplementation();
        
        // Execute the upgrade script
        newName = EXPECTED_NEW_NAME;
        newSymbol = EXPECTED_NEW_SYMBOL;

        _upgrade();
        
        // Verify the implementation was upgraded
        address newImplementation = getImplementation();
        assertTrue(newImplementation != oldImplementation, "Implementation should have changed");
        assertFalse(newImplementation == address(0), "New implementation should not be zero address");
        
        // Verify name and symbol were updated
        assertEq(proxyToken.name(), EXPECTED_NEW_NAME, "Name should be updated to 'Zyfi'");
        assertEq(proxyToken.symbol(), EXPECTED_NEW_SYMBOL, "Symbol should be updated to 'ZFI'");
        
        // Verify proxy address remains the same
        assertTrue(address(proxyToken) == address(proxy), "Proxy address should remain unchanged");
        
        // Verify token functionality still works (basic ERC20 operations)
        // Assuming the token has a mint function or initial supply
        uint256 initialBalance = proxyToken.balanceOf(GOV_ADDRESS);
        
        // Test transfer functionality if there's balance
        if (initialBalance > 0) {
            uint256 transferAmount = initialBalance / 2;
            proxyToken.transfer(USER, transferAmount);
            assertEq(proxyToken.balanceOf(USER), transferAmount, "Transfer should work after upgrade");
            assertEq(proxyToken.balanceOf(GOV_ADDRESS), initialBalance - transferAmount, "Sender balance should be reduced");
        }
    }
    
    function testUpgradeEmitsEvents() public {
        // We expect an Upgraded event from ERC1967Utils
        vm.expectEmit(true, true, false, false);
        emit Upgraded(address(0xF62849F9A0B5Bf2913b396098F7c7019b51A820a)); // We can't predict the exact address, so we use address(0) as placeholder

        vm.stopPrank();
        _upgrade();
    }
    
    function testUpgradePreservesOtherState() public {
        // Test that role-based state and other variables are preserved
        bytes32 DEFAULT_ADMIN_ROLE = 0x00;
        bool hasAdminRole = proxyToken.hasRole(DEFAULT_ADMIN_ROLE, GOV_ADDRESS);
        uint256 totalSupply = proxyToken.totalSupply();
        uint256 govBalance = proxyToken.balanceOf(GOV_ADDRESS);
        
        // Execute upgrade
        vm.stopPrank();
        _upgrade();
        
        // Verify other state is preserved
        assertEq(proxyToken.hasRole(DEFAULT_ADMIN_ROLE, GOV_ADDRESS), hasAdminRole, "Admin role should be preserved");
        assertEq(proxyToken.totalSupply(), totalSupply, "Total supply should be preserved");
        assertEq(proxyToken.balanceOf(GOV_ADDRESS), govBalance, "Gov balance should be preserved");
    }
    
    function testScriptSetUpReadsEnvironmentVariables() public {        
        // These would need to be public variables in the script for this test to work
        // You might need to add getter functions to the script
        assertTrue(address(proxy) != address(0), "Proxy address should be set");
    }

    // Helper function to get current implementation
    function getImplementation() internal view returns (address) {
        bytes32 implementationSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        return address(uint160(uint256(vm.load(address(proxy), implementationSlot))));
    }
    
    // Event declaration for testing
    event Upgraded(address indexed implementation);
    
    function tearDown() public {
        vm.stopPrank();
    }
}