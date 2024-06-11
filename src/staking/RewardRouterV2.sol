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
    address public stZfi;

    address public stakedOdyTracker; //TODO: test this file + remove references to old names

    address public odyVester;

    mapping (address => address) public pendingReceivers;

    event StakeOdy(address account, address token, uint256 amount);
    event UnstakeOdy(address account, address token, uint256 amount);

    function initialize(
        address _ody,
        address _stZfi,
        address _stakedOdyTracker,
        address _odyVester
    ) external onlyGov {
        require(!isInitialized, "RewardRouter: already initialized");
        isInitialized = true;

        zfi = _ody;
        stZfi = _stZfi;

        stakedOdyTracker = _stakedOdyTracker;

        odyVester = _odyVester;
    }

    // to help users who accidentally send their tokens to this contract
    function rescueFunds(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function batchStakeOdyForAccount(address[] memory _accounts, uint256[] memory _amounts) external nonReentrant onlyGov {
        address _ody = zfi;
        for (uint256 i = 0; i < _accounts.length; i++) {
            _stakeOdy(msg.sender, _accounts[i], _ody, _amounts[i]);
        }
    }

    function stakeOdyForAccount(address _account, uint256 _amount) external nonReentrant onlyGov {
        _stakeOdy(msg.sender, _account, zfi, _amount);
    }

    function stakeOdy(uint256 _amount) external nonReentrant {
        _stakeOdy(msg.sender, msg.sender, zfi, _amount);
    }

    function stakeEsOdy(uint256 _amount) external nonReentrant {
        _stakeOdy(msg.sender, msg.sender, stZfi, _amount);
    }

    function claimEsOdy() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(stakedOdyTracker).claimForAccount(account, account);
    }

    function compound() external nonReentrant {
        _compound(msg.sender);
    }

    function compoundForAccount(address _account) external nonReentrant onlyGov {
        _compound(_account);
    }

    function handleRewards(
        bool _shouldClaimOdy,
        bool _shouldStakeOdy,
        bool _shouldClaimEsOdy,
        bool _shouldStakeEsOdy
    ) external nonReentrant {
        address account = msg.sender;

        uint256 odyAmount = 0;
        if (_shouldClaimOdy) {
            odyAmount = IVester(odyVester).claimForAccount(account, account);
        }

        if (_shouldStakeOdy && odyAmount > 0) {
            _stakeOdy(account, account, zfi, odyAmount);
        }

        uint256 stZfiAmount = 0;
        if (_shouldClaimEsOdy) {
            stZfiAmount = IRewardTracker(stakedOdyTracker).claimForAccount(account, account);
        }

        if (_shouldStakeEsOdy && stZfiAmount > 0) {
            _stakeOdy(account, account, stZfi, stZfiAmount);
        }
    }

    function batchCompoundForAccounts(address[] memory _accounts) external nonReentrant onlyGov {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _compound(_accounts[i]);
        }
    }

    // the _validateReceiver function checks that cumulativeRewards values of an account are zero,
    // this is to help ensure that vesting calculations can be done correctly
    // cumulativeRewards is updated if the claimable reward for an account is more than zero
    // it is possible for multiple transfers to be sent into a single account, using signalTransfer and
    // acceptTransfer, if those values have not been updated yet
    function signalTransfer(address _receiver) external nonReentrant {
        require(IERC20(odyVester).balanceOf(msg.sender) == 0, "RewardRouter: sender has vested tokens");

        _validateReceiver(_receiver);
        pendingReceivers[msg.sender] = _receiver;
    }

    function acceptTransfer(address _sender) external nonReentrant {
        require(IERC20(odyVester).balanceOf(_sender) == 0, "RewardRouter: sender has vested tokens");

        address receiver = msg.sender;
        require(pendingReceivers[_sender] == receiver, "RewardRouter: transfer not signalled");
        delete pendingReceivers[_sender];

        _validateReceiver(receiver);
        _compound(_sender);

        uint256 stakedOdy = IRewardTracker(stakedOdyTracker).depositBalances(_sender, zfi);
        if (stakedOdy > 0) {
            _unstakeOdy(_sender, zfi, stakedOdy);
            _stakeOdy(_sender, receiver, zfi, stakedOdy);
        }

        uint256 stakedEsOdy = IRewardTracker(stakedOdyTracker).depositBalances(_sender, stZfi);
        if (stakedEsOdy > 0) {
            _unstakeOdy(_sender, stZfi, stakedEsOdy);
            _stakeOdy(_sender, receiver, stZfi, stakedEsOdy);
        }

        uint256 stZfiBalance = IERC20(stZfi).balanceOf(_sender);
        if (stZfiBalance > 0) {
            IERC20(stZfi).transferFrom(_sender, receiver, stZfiBalance);
        }

        IVester(odyVester).transferStakeValues(_sender, receiver);
    }

    function _validateReceiver(address _receiver) private view {
        require(IRewardTracker(stakedOdyTracker).cumulativeRewards(_receiver) == 0, "RewardRouter: stakedOdyTracker.cumulativeRewards > 0");
        require(IVester(odyVester).transferredCumulativeRewards(_receiver) == 0, "RewardRouter: odyVester.transferredCumulativeRewards > 0");
        require(IERC20(odyVester).balanceOf(_receiver) == 0, "RewardRouter: odyVester.balance > 0");
    }

    function _compound(address _account) private {
        _compoundOdy(_account);
    }

    function _compoundOdy(address _account) private {
        uint256 stZfiAmount = IRewardTracker(stakedOdyTracker).claimForAccount(_account, _account);
        if (stZfiAmount > 0) {
            _stakeOdy(_account, _account, stZfi, stZfiAmount);
        }
    }

    function _stakeOdy(address _fundingAccount, address _account, address _token, uint256 _amount) private {
        require(_amount > 0, "RewardRouter: invalid _amount");
        IRewardTracker(stakedOdyTracker).stakeForAccount(_fundingAccount, _account, _token, _amount);
        emit StakeOdy(_account, _token, _amount);
    }

    function _unstakeOdy(address _account, address _token, uint256 _amount) private {
        require(_amount > 0, "RewardRouter: invalid _amount");
        IRewardTracker(stakedOdyTracker).unstakeForAccount(_account, _token, _amount, _account);
        emit UnstakeOdy(_account, _token, _amount);
    }
}
