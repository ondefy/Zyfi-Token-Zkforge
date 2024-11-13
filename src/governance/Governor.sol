//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {GovernorVotes} from "@openzeppelin/contracts/governance/GovernorVotes.sol";
/**
 * @notice ZfiGovernor governor contract
 */
contract ZfiGovernor is GovernorVotes {
    constructor(string memory name) Governor(name) {
    }
}