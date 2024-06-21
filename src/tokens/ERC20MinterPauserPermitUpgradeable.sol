// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract ERC20MinterPauserPermitUpgradeable is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, PausableUpgradeable, AccessControlUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant TRANSFERRER_ROLE = keccak256("TRANSFERRER_ROLE");

    bool private _inPrivateTransferMode;

    function initialize(string memory name, string memory symbol) initializer public {
        __ERC20_init(name, symbol);
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init(name);
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * @dev Returns whether the token is in private transfer mode
     */
    function inPrivateTransferMode() public view virtual returns (bool) {
        return _inPrivateTransferMode;
    }

    /**
     * @dev Sets the values for {inPrivateTransferMode}.
     */
    function setInPrivateTransferMode(bool inPrivateTransferMode_) external onlyRole(DEFAULT_ADMIN_ROLE){
        _inPrivateTransferMode = inPrivateTransferMode_;
    }

    /**
     * @dev overrides transfer method to restrict use to accounts with TRANSFERRER_ROLE while in private transfer mode
     */
    function transfer(address to, uint256 amount) public virtual override whenNotPaused returns (bool) {
        if (_inPrivateTransferMode) {
            require(hasRole(TRANSFERRER_ROLE, _msgSender()), "AccessControl: account is missing transferrer role to transfer in private transfer mode");
        }
        return super.transfer(to, amount);
    }

    /**
     * @dev overrides transferFrom to allow addresses with TRANSFERRER_ROLE to bypass allowance check
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override whenNotPaused returns (bool) {
        if (hasRole(TRANSFERRER_ROLE, _msgSender())) {
            _transfer(from, to, amount);
            return true;
        } else if (_inPrivateTransferMode) {
            revert("AccessControl: account is missing transferrer role to transfer in private transfer mode");
        }
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev overrides burnFrom to remove allowance check and to only be callable by accounts with MINTER_ROLE
     */
    function burnFrom(address account, uint256 amount) public virtual override onlyRole(MINTER_ROLE){
        _burn(account, amount);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
