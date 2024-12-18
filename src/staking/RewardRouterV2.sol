// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/IRewardTracker.sol";
import "./interfaces/IVester.sol";
import "../access/Governable.sol";

contract RewardRouterV2 is ReentrancyGuard, Governable {
    using SafeERC20 for IERC20;

    bool public isInitialized;

    address public zfi;

    address public stakedZfiTracker;

    address public zfiVester;

    mapping(address => address) public pendingReceivers;

    event StakeZfi(address account, uint256 amount);
    event UnstakeZfi(address account, uint256 amount);

    function initialize(
        address _zfi,
        address _stakedZfiTracker,
        address _zfiVester
    ) external onlyGov {
        require(!isInitialized, "RewardRouter: already initialized");
        if (
            _zfi == address(0) ||
            _stakedZfiTracker == address(0) ||
            _zfiVester == address(0)
        ) {
            revert ZeroAddressError();
        }
        isInitialized = true;

        zfi = _zfi;

        stakedZfiTracker = _stakedZfiTracker;

        zfiVester = _zfiVester;
    }

    // to help users who accidentally send their tokens to this contract
    function rescueFunds(
        address _token,
        address _account,
        uint256 _amount
    ) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function batchStakeZfiForAccount(address[] memory _accounts, uint256[] memory _amounts) external nonReentrant onlyGov {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _stakeZfi(msg.sender, _accounts[i], _amounts[i]);
        }
    }

    function stakeZfiForAccount(address _account, uint256 _amount) external nonReentrant onlyGov {
        _stakeZfi(msg.sender, _account, _amount);
    }

    function stakeZfi(uint256 _amount) external nonReentrant {
        _stakeZfi(msg.sender, msg.sender, _amount);
    }

    function claimStZfi() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(stakedZfiTracker).claimForAccount(account, account);
    }

    function compound() external nonReentrant {
        _compound(msg.sender);
    }

    function compoundForAccount(
        address _account
    ) external nonReentrant onlyGov {
        _compound(_account);
    }

    function handleRewards(
        bool _shouldClaimZfi,
        bool _shouldStakeZfi,
        bool _shouldClaimStZfi
    ) external nonReentrant returns (uint256 stZfiAmount) {
        address account = msg.sender;

        uint256 zfiAmount = 0;
        if (_shouldClaimZfi) {
            zfiAmount = IVester(zfiVester).claimForAccount(account, account);
        }

        if (_shouldStakeZfi && zfiAmount > 0) {
            _stakeZfi(account, account, zfiAmount);
        }

        if (_shouldClaimStZfi) {
            stZfiAmount = IRewardTracker(stakedZfiTracker).claimForAccount(
                account,
                account
            );
        }
    }

    function batchCompoundForAccounts(
        address[] memory _accounts
    ) external nonReentrant onlyGov {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _compound(_accounts[i]);
        }
    }

    function _compound(address _account) private {
        _compoundZfi(_account);
    }

    function _compoundZfi(address _account) private {
        IRewardTracker(stakedZfiTracker).claimForAccount(_account, _account);
    }

    function _stakeZfi(address _fundingAccount, address _account, uint256 _amount) private {
        require(_amount > 0, "RewardRouter: invalid _amount");
        IRewardTracker(stakedZfiTracker).stakeForAccount(_fundingAccount, _account, _amount);
        emit StakeZfi(_account, _amount);
    }

    function _unstakeZfi(address _account, uint256 _amount) private {
        require(_amount > 0, "RewardRouter: invalid _amount");
        IRewardTracker(stakedZfiTracker).unstakeForAccount(_account, _amount, _account);
        emit UnstakeZfi(_account, _amount);
    }
}
