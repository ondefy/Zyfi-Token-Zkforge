// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IRewardTracker.sol";
import "./interfaces/IVester.sol";
import "../access/Governable.sol";

contract RewardRouterV2 is ReentrancyGuard, Governable {
    using SafeERC20 for IERC20;

    bool public isInitialized;

    address public ody;
    address public esOdy;

    address public stakedOdyTracker;

    address public odyVester;

    mapping (address => address) public pendingReceivers;

    event StakeOdy(address account, address token, uint256 amount);
    event UnstakeOdy(address account, address token, uint256 amount);

    function initialize(
        address _ody,
        address _esOdy,
        address _stakedOdyTracker,
        address _odyVester
    ) external onlyGov {
        require(!isInitialized, "RewardRouter: already initialized");
        isInitialized = true;

        ody = _ody;
        esOdy = _esOdy;

        stakedOdyTracker = _stakedOdyTracker;

        odyVester = _odyVester;
    }

    // to help users who accidentally send their tokens to this contract
    function rescueFunds(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function batchStakeOdyForAccount(address[] memory _accounts, uint256[] memory _amounts) external nonReentrant onlyGov {
        address _ody = ody;
        for (uint256 i = 0; i < _accounts.length; i++) {
            _stakeOdy(msg.sender, _accounts[i], _ody, _amounts[i]);
        }
    }

    function stakeOdyForAccount(address _account, uint256 _amount) external nonReentrant onlyGov {
        _stakeOdy(msg.sender, _account, ody, _amount);
    }

    function stakeOdy(uint256 _amount) external nonReentrant {
        _stakeOdy(msg.sender, msg.sender, ody, _amount);
    }

    function stakeEsOdy(uint256 _amount) external nonReentrant {
        _stakeOdy(msg.sender, msg.sender, esOdy, _amount);
    }

    function unstakeOdy(uint256 _amount) external nonReentrant {
        _unstakeOdy(msg.sender, ody, _amount);
    }

    function unstakeEsOdy(uint256 _amount) external nonReentrant {
        _unstakeOdy(msg.sender, esOdy, _amount);
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
            _stakeOdy(account, account, ody, odyAmount);
        }

        uint256 esOdyAmount = 0;
        if (_shouldClaimEsOdy) {
            esOdyAmount = IRewardTracker(stakedOdyTracker).claimForAccount(account, account);
        }

        if (_shouldStakeEsOdy && esOdyAmount > 0) {
            _stakeOdy(account, account, esOdy, esOdyAmount);
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

        uint256 stakedOdy = IRewardTracker(stakedOdyTracker).depositBalances(_sender, ody);
        if (stakedOdy > 0) {
            _unstakeOdy(_sender, ody, stakedOdy);
            _stakeOdy(_sender, receiver, ody, stakedOdy);
        }

        uint256 stakedEsOdy = IRewardTracker(stakedOdyTracker).depositBalances(_sender, esOdy);
        if (stakedEsOdy > 0) {
            _unstakeOdy(_sender, esOdy, stakedEsOdy);
            _stakeOdy(_sender, receiver, esOdy, stakedEsOdy);
        }

        uint256 esOdyBalance = IERC20(esOdy).balanceOf(_sender);
        if (esOdyBalance > 0) {
            IERC20(esOdy).transferFrom(_sender, receiver, esOdyBalance);
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
        uint256 esOdyAmount = IRewardTracker(stakedOdyTracker).claimForAccount(_account, _account);
        if (esOdyAmount > 0) {
            _stakeOdy(_account, _account, esOdy, esOdyAmount);
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
