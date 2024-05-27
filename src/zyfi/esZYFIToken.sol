//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../tokens/ERC20MinterPauserPermitUpgradeable.sol";

/**
 * @notice esODY token contract
 */
contract esZYFIToken is ERC20MinterPauserPermitUpgradeable {
    /**
     * @notice Intializer
     * @param _ONDEFYDAO the address of the owner
     */
    function initialize2(address _ONDEFYDAO) public initializer {
        super.initialize("Escrowed ZYFI", "esODY");
        _grantRole(DEFAULT_ADMIN_ROLE, _ONDEFYDAO);
    }
}