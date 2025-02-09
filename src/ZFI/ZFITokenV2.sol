//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../tokens/ERC20MinterPauserPermitUpgradeable.sol";

/**
 * @notice ZYFIToken token contract
 */
contract ZFITokenV2 is ERC20MinterPauserPermitUpgradeable {
    // /**
    //  * @notice Intializer
    //  * @param _ONDEFYDAO the address of the owner
    //  */
    // function initialize2(address _ONDEFYDAO) public initializer {
    //     super.initialize("Zyfi Token", "ZFI");
    //     _grantRole(DEFAULT_ADMIN_ROLE, _ONDEFYDAO);
    // }

    function setName(string memory name_) external onlyRole(DEFAULT_ADMIN_ROLE){
        ERC20Storage storage $;
        bytes32 ERC20StorageLocation = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;
        assembly {
            $.slot := ERC20StorageLocation
        }
        $._name = name_;
    }
}