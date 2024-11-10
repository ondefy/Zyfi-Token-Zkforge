//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../tokens/ERC20MinterPauserPermitUpgradeable.sol";

/**
 * @notice ZYFIToken token contract
 */
contract ZFIToken is ERC20MinterPauserPermitUpgradeable {
    /**
     * @notice Intializer
     * @param _ONDEFYDAO the address of the owner
     */
    function initialize2(address _ONDEFYDAO) public initializer {
        super.initialize("ToToro Test Token", "TTT2");
        _grantRole(DEFAULT_ADMIN_ROLE, _ONDEFYDAO);
    }

    
}