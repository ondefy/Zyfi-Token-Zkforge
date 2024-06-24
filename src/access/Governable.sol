// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Governable {
    event GovSet(address newGov);

    address public gov;

    constructor() {
        gov = msg.sender;
    }

    modifier onlyGov() {
        require(msg.sender == gov, "Governable: forbidden");
        _;
    }

    function setGov(address _gov) external onlyGov {
        gov = _gov;
        emit GovSet(_gov);
    }
}
