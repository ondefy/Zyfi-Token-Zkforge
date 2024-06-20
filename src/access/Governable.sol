// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Governable {
    error ZeroAddressError();

    address public gov;

    constructor() {
        gov = msg.sender;
    }

    modifier onlyGov() {
        require(msg.sender == gov, "Governable: forbidden");
        _;
    }

    function setGov(address _gov) external onlyGov {
        if (_gov == address(0)) {
            revert ZeroAddressError();
        }
        gov = _gov;
    }
}
