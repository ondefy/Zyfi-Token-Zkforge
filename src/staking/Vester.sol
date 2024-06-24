// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IRewardTracker.sol";
import "./interfaces/IVester.sol";
import "../tokens/interfaces/IERC20Burnable.sol";
import "../access/Governable.sol";

contract Vester is IVester, IERC20, ReentrancyGuard, Governable {
    using SafeERC20 for IERC20;

    uint256 public immutable vestingDuration;
    address public immutable esToken;
    address public immutable claimableToken;
    address public immutable override rewardTracker;

    string public name;
    string public symbol;
    uint8 public decimals = 18;

    uint256 public override totalSupply;

    bool public hasMaxVestableAmount;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public override cumulativeClaimAmounts;
    mapping(address => uint256) public override claimedAmounts;
    mapping(address => uint256) public lastVestingTimes;

    mapping(address => uint256) public override transferredCumulativeRewards;
    mapping(address => uint256) public override cumulativeRewardDeductions;
    mapping(address => uint256) public override bonusRewards;

    mapping(address => bool) public isHandler;

    event Claim(address receiver, uint256 amount);
    event Deposit(address account, uint256 amount);
    event Withdraw(address account, uint256 claimedAmount, uint256 balance);
    event HandlerSet(address handler, bool isActive);
    event HasMaxVestableAmountSet(bool hasMaxVestableAmount);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _vestingDuration,
        address _esToken,
        address _claimableToken,
        address _rewardTracker
    ) {
        if (
            _esToken == address(0) ||
            _claimableToken == address(0) ||
            _rewardTracker == address(0)
        ) {
            revert ZeroAddressError();
        }
        name = _name;
        symbol = _symbol;

        vestingDuration = _vestingDuration;

        esToken = _esToken;
        claimableToken = _claimableToken;

        rewardTracker = _rewardTracker;

        if (rewardTracker != address(0)) {
            hasMaxVestableAmount = true;
        }
    }

    function setHandler(address _handler, bool _isActive) external onlyGov {
        isHandler[_handler] = _isActive;
        emit HandlerSet(_handler, _isActive);
    }

    function setHasMaxVestableAmount(
        bool _hasMaxVestableAmount
    ) external onlyGov {
        hasMaxVestableAmount = _hasMaxVestableAmount;
        emit HasMaxVestableAmountSet(_hasMaxVestableAmount);
    }

    function deposit(uint256 _amount) external nonReentrant {
        _deposit(msg.sender, _amount);
    }

    function depositForAccount(
        address _account,
        uint256 _amount
    ) external nonReentrant {
        _validateHandler();
        _deposit(_account, _amount);
    }

    function claim() external nonReentrant returns (uint256) {
        return _claim(msg.sender, msg.sender);
    }

    function claimForAccount(
        address _account,
        address _receiver
    ) external override nonReentrant returns (uint256) {
        _validateHandler();
        return _claim(_account, _receiver);
    }

    // to help users who accidentally send their tokens to this contract
    function rescueFunds(
        address _token,
        address _account,
        uint256 _amount
    ) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function withdraw() external nonReentrant {
        address account = msg.sender;
        address _receiver = account;
        _claim(account, _receiver);

        uint256 claimedAmount = cumulativeClaimAmounts[account];
        uint256 balance = balances[account];
        uint256 totalVested = balance + claimedAmount;
        require(totalVested > 0, "Vester: vested amount is zero");

        // stake the ZFI token for the user

        IRewardTracker(rewardTracker).stakeForAccount(
            address(this),
            _receiver,
            address(claimableToken),
            balance
        );

        _burn(account, balance);

        delete cumulativeClaimAmounts[account];
        delete claimedAmounts[account];
        delete lastVestingTimes[account];

        emit Withdraw(account, claimedAmount, balance);
    }

    function transferStakeValues(
        address _sender,
        address _receiver
    ) external override nonReentrant {
        _validateHandler();

        uint256 transferredCumulativeReward = transferredCumulativeRewards[
            _sender
        ];
        uint256 cumulativeReward = IRewardTracker(rewardTracker)
            .cumulativeRewards(_sender);

        transferredCumulativeRewards[_receiver] =
            transferredCumulativeReward +
            cumulativeReward;
        cumulativeRewardDeductions[_sender] = cumulativeReward;
        transferredCumulativeRewards[_sender] = 0;

        bonusRewards[_receiver] = bonusRewards[_sender];
        bonusRewards[_sender] = 0;
    }

    function setTransferredCumulativeRewards(
        address _account,
        uint256 _amount
    ) external override nonReentrant {
        _validateHandler();
        transferredCumulativeRewards[_account] = _amount;
    }

    function setCumulativeRewardDeductions(
        address _account,
        uint256 _amount
    ) external override nonReentrant {
        _validateHandler();
        cumulativeRewardDeductions[_account] = _amount;
    }

    function setBonusRewards(
        address _account,
        uint256 _amount
    ) external override nonReentrant {
        _validateHandler();
        bonusRewards[_account] = _amount;
    }

    function claimable(
        address _account
    ) public view override returns (uint256) {
        uint256 amount = cumulativeClaimAmounts[_account] -
            claimedAmounts[_account];
        uint256 nextClaimable = _getNextClaimableAmount(_account);
        return amount + nextClaimable;
    }

    function getMaxVestableAmount(
        address _account
    ) public view override returns (uint256) {
        if (!hasRewardTracker()) {
            return 0;
        }

        uint256 transferredCumulativeReward = transferredCumulativeRewards[
            _account
        ];
        uint256 bonusReward = bonusRewards[_account];
        uint256 cumulativeReward = IRewardTracker(rewardTracker)
            .cumulativeRewards(_account);
        uint256 maxVestableAmount = cumulativeReward +
            transferredCumulativeReward +
            bonusReward;

        uint256 cumulativeRewardDeduction = cumulativeRewardDeductions[
            _account
        ];

        unchecked {
            if (maxVestableAmount < cumulativeRewardDeduction) {
                return 0;
            }
            return maxVestableAmount - cumulativeRewardDeduction;
        }
    }

    function hasRewardTracker() public view returns (bool) {
        return rewardTracker != address(0);
    }

    function getTotalVested(address _account) public view returns (uint256) {
        return balances[_account] + cumulativeClaimAmounts[_account];
    }

    function balanceOf(
        address _account
    ) public view override returns (uint256) {
        return balances[_account];
    }

    // empty implementation, tokens are non-transferrable
    function transfer(
        address /* recipient */,
        uint256 /* amount */
    ) public pure override returns (bool) {
        revert("Vester: non-transferrable");
    }

    // empty implementation, tokens are non-transferrable
    function allowance(
        address /* owner */,
        address /* spender */
    ) public view virtual override returns (uint256) {
        return 0;
    }

    // empty implementation, tokens are non-transferrable
    function approve(
        address /* spender */,
        uint256 /* amount */
    ) public virtual override returns (bool) {
        revert("Vester: non-transferrable");
    }

    // empty implementation, tokens are non-transferrable
    function transferFrom(
        address /* sender */,
        address /* recipient */,
        uint256 /* amount */
    ) public virtual override returns (bool) {
        revert("Vester: non-transferrable");
    }

    function getVestedAmount(
        address _account
    ) public view override returns (uint256) {
        uint256 balance = balances[_account];
        uint256 cumulativeClaimAmount = cumulativeClaimAmounts[_account];
        return balance + cumulativeClaimAmount;
    }

    function _mint(address _account, uint256 _amount) private {
        require(_account != address(0), "Vester: mint to the zero address");

        totalSupply = totalSupply + _amount;
        balances[_account] = balances[_account] + _amount;

        emit Transfer(address(0), _account, _amount);
    }

    function _burn(address _account, uint256 _amount) private {
        require(_account != address(0), "Vester: burn from the zero address");

        balances[_account] = balances[_account] - _amount; // "Vester: burn amount exceeds balance"
        totalSupply = totalSupply - _amount;

        emit Transfer(_account, address(0), _amount);
    }

    function _deposit(address _account, uint256 _amount) private {
        require(_amount > 0, "Vester: invalid _amount");

        _updateVesting(_account);

        // unstake for the user
        IRewardTracker(rewardTracker).unstakeForAccount(
            _account,
            claimableToken,
            _amount,
            address(this)
        );

        _mint(_account, _amount);

        if (hasMaxVestableAmount) {
            uint256 maxAmount = getMaxVestableAmount(_account);
            require(
                getTotalVested(_account) <= maxAmount,
                "Vester: max vestable amount exceeded"
            );
        }

        emit Deposit(_account, _amount);
    }

    function _updateVesting(address _account) private {
        uint256 amount = _getNextClaimableAmount(_account);
        lastVestingTimes[_account] = block.timestamp;

        if (amount == 0) {
            return;
        }

        // transfer claimableAmount from balances to cumulativeClaimAmounts
        _burn(_account, amount);
        cumulativeClaimAmounts[_account] =
            cumulativeClaimAmounts[_account] +
            amount;
    }

    function _getNextClaimableAmount(
        address _account
    ) private view returns (uint256) {
        uint256 timeDiff = block.timestamp - lastVestingTimes[_account];

        uint256 balance = balances[_account];
        if (balance == 0) {
            return 0;
        }

        uint256 vestedAmount = getVestedAmount(_account);
        uint256 claimableAmount = Math.mulDiv(
            vestedAmount,
            timeDiff,
            vestingDuration
        );

        if (claimableAmount < balance) {
            return claimableAmount;
        }

        return balance;
    }

    function _claim(
        address _account,
        address _receiver
    ) private returns (uint256) {
        _updateVesting(_account);
        uint256 amount = claimable(_account);
        claimedAmounts[_account] = claimedAmounts[_account] + amount;

        IERC20(claimableToken).transfer(_receiver, amount);

        emit Claim(_account, amount);
        return amount;
    }

    function _validateHandler() private view {
        require(isHandler[msg.sender], "Vester: forbidden");
    }
}
