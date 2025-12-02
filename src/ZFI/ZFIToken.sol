//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../tokens/ERC20MinterPauserPermitUpgradeable.sol";

/**
 * @notice ZYFIToken token contract
 */
contract ZFIToken is ERC20MinterPauserPermitUpgradeable {
    /**
     * @notice Emitted when the token name and symbol are updated
     * @param previousName The previous token name
     * @param newName The new token name
     * @param previousSymbol The previous token symbol
     * @param newSymbol The new token symbol
     */
    event NameAndSymbolUpdated(
        string previousName,
        string newName,
        string previousSymbol,
        string newSymbol
    );

    /**
     * @notice Intializer
     * @param _ONDEFYDAO the address of the owner
     */
    function initialize2(address _ONDEFYDAO) public initializer {
        super.initialize("Zyfi Token", "ZFI");
        _grantRole(DEFAULT_ADMIN_ROLE, _ONDEFYDAO);
    }

    function updateNameAndSymbol(string memory name_, string memory symbol_) public onlyRole(DEFAULT_ADMIN_ROLE) {
        ERC20Storage storage $ = _ERC20Storage();
        
        // Store previous values for the event
        string memory previousName = $._name;
        string memory previousSymbol = $._symbol;
        
        // Update the values
        $._name = name_;
        $._symbol = symbol_;
        
        // Emit the event
        emit NameAndSymbolUpdated(previousName, name_, previousSymbol, symbol_);
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC20StorageLocation = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

    function _ERC20Storage() private pure returns (ERC20Storage storage $) {
        assembly {
            $.slot := ERC20StorageLocation
        }
    }
}