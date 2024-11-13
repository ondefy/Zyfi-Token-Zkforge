// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/governance/utils/Votes.sol";

import "./interfaces/IRewardDistributor.sol";
import "./interfaces/IRewardTracker.sol";
import "../access/Governable.sol";

contract RewardTracker is IERC20, ReentrancyGuard, IRewardTracker, Governable, Votes {
    using SafeERC20 for IERC20;

    error AuthorizationError();
    error BoostTooHigh();
    /**
     * @dev Total supply cap has been exceeded, introducing a risk of votes overflowing.
     */
    error ERC20ExceededSafeSupply(uint256 increasedSupply, uint256 cap);

    event Claim(address receiver, uint256 amount);
    event HandlerSet(address handler, bool isSet);
    event DepositTokenSet(address token, bool isDepositToken);
    event PrivateClaimingModeSet(bool value);
    event PrivateStakingModeSet(bool value);
    event PrivateTransferModeSet(bool value);
    event RewardBoostSet(address account, uint256 rewardBoostBasisPoints);

    uint256 public constant BASIS_POINTS_DIVISOR = 100_00;
    uint256 public constant PRECISION = 1e30;

    uint8 public constant decimals = 18;

    bool public isInitialized;

    string public name;
    string public symbol;
    address immutable public depositToken;

    address public distributor;
    mapping (address => uint256) public override depositBalances;
    uint256 public totalDepositSupply;

    uint256 public override totalSupply;
    uint256 public override boostedTotalSupply;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    uint256 public cumulativeRewardPerToken;
    mapping(address => uint256) public override rewardBoostsBasisPoints;
    mapping(address => uint256) public override stakedAmounts;
    mapping(address => uint256) public override boostedStakedAmounts;
    mapping(address => uint256) public claimableReward;
    mapping(address => uint256) public previousCumulatedRewardPerToken;
    mapping(address => uint256) public override cumulativeRewards;

    bool public inPrivateTransferMode;
    bool public inPrivateStakingMode;
    bool public inPrivateClaimingMode;
    mapping(address => bool) public isHandler;

    constructor(string memory _name, string memory _symbol, address _depositToken) Governable() EIP712(_name, "1") {
        name = _name;
        symbol = _symbol;
        depositToken = _depositToken;
    }

    function initialize(
        address _distributor
    ) external onlyGov {
        require(!isInitialized, "RewardTracker: already initialized");
        isInitialized = true;
        distributor = _distributor;
    }

    function setInPrivateTransferMode(bool _inPrivateTransferMode) external onlyGov {
        inPrivateTransferMode = _inPrivateTransferMode;
        emit PrivateTransferModeSet(_inPrivateTransferMode);
    }

    function setInPrivateStakingMode(
        bool _inPrivateStakingMode
    ) external onlyGov {
        inPrivateStakingMode = _inPrivateStakingMode;
        emit PrivateStakingModeSet(_inPrivateStakingMode);
    }

    function setInPrivateClaimingMode(
        bool _inPrivateClaimingMode
    ) external onlyGov {
        inPrivateClaimingMode = _inPrivateClaimingMode;
        emit PrivateClaimingModeSet(_inPrivateClaimingMode);
    }

    function setHandler(address _handler, bool _isActive) external onlyGov {
        isHandler[_handler] = _isActive;
        emit HandlerSet(_handler, _isActive);
    }

    function setRewardBoost(
        address _account,
        uint256 _rewardBoostBasisPoints
    ) external onlyGov {
        _setRewardBoost(_account, _rewardBoostBasisPoints);
    }

    function batchSetRewardBoost(
        address[] memory _accounts,
        uint256[] memory _rewardBoostBasisPoints
    ) external onlyGov {
        require(
            _accounts.length == _rewardBoostBasisPoints.length,
            "RewardTracker: array length mismatch"
        );

        for (uint256 i = 0; i < _accounts.length; i++) {
            _setRewardBoost(_accounts[i], _rewardBoostBasisPoints[i]);
        }
    }

    // to help users who accidentally send their tokens to this contract
    function rescueFunds(
        address _token,
        address _account,
        uint256 _amount
    ) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    /**
     * @dev Maximum token supply. Defaults to `type(uint208).max` (2^208^ - 1).
     *
     * This maximum is enforced in {_update}. It limits the total supply of the token, which is otherwise a uint256,
     * so that checkpoints can be stored in the Trace208 structure used by {{Votes}}. Increasing this value will not
     * remove the underlying limitation, and will cause {_update} to fail because of a math overflow in
     * {_transferVotingUnits}. An override could be used to further restrict the total supply (to a lower value) if
     * additional logic requires it. When resolving override conflicts on this function, the minimum should be
     * returned.
     */
    function _maxSupply() internal view virtual returns (uint256) {
        return type(uint208).max;
    }

    function balanceOf(
        address _account
    ) external view override returns (uint256) {
        return balances[_account];
    }

    function stake(uint256 _amount) external override nonReentrant {
        if (inPrivateStakingMode) { 
            revert AuthorizationError();
        }
        _stake(msg.sender, msg.sender, _amount);
    }

    function stakeForAccount(address _fundingAccount, address _account, uint256 _amount) external override nonReentrant {
        _validateHandler();
        _stake(_fundingAccount, _account, _amount);
    }

    // removed the unstake function: only the vester can unstakeForAccount
    function unstakeForAccount(address _account, uint256 _amount, address _receiver) external override nonReentrant {
        _validateHandler();
        _unstake(_account, _amount, _receiver);
    }

    function transfer(
        address _recipient,
        uint256 _amount
    ) external override returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function allowance(
        address _owner,
        address _spender
    ) external view override returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(
        address _spender,
        uint256 _amount
    ) external override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external override returns (bool) {
        if (isHandler[msg.sender]) {
            _transfer(_sender, _recipient, _amount);
            return true;
        }

        uint256 nextAllowance = allowances[_sender][msg.sender] - _amount; // "RewardTracker: transfer amount exceeds allowance"
        _approve(_sender, msg.sender, nextAllowance);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function tokensPerInterval() external view override returns (uint256) {
        return IRewardDistributor(distributor).tokensPerInterval();
    }

    function updateRewards() external override nonReentrant {
        _updateRewards(address(0));
    }

    function claim(address _receiver) external override nonReentrant returns (uint256) {
        if (inPrivateClaimingMode) { 
            revert AuthorizationError();
        }
        return _claim(msg.sender, _receiver);
    }

    function claimForAccount(
        address _account,
        address _receiver
    ) external override nonReentrant returns (uint256) {
        _validateHandler();
        return _claim(_account, _receiver);
    }

    function claimable(
        address _account
    ) public view override returns (uint256) {
        uint256 boostedStakedAmount = boostedStakedAmounts[_account];
        if (boostedStakedAmount == 0) {
            return claimableReward[_account];
        }
        uint256 pendingRewards = Math.mulDiv(
            IRewardDistributor(distributor).pendingRewards(),
            PRECISION,
            boostedTotalSupply
        );
        uint256 nextCumulativeRewardPerToken = cumulativeRewardPerToken +
            pendingRewards;

        uint256 rewards = Math.mulDiv(
            boostedStakedAmount,
            nextCumulativeRewardPerToken -
                previousCumulatedRewardPerToken[_account],
            PRECISION
        );
        return claimableReward[_account] + rewards;
    }

    function rewardToken() public view returns (address) {
        return IRewardDistributor(distributor).rewardToken();
    }

    function _setRewardBoost(address _account, uint256 _rewardBoostBasisPoints) private {
        if (_rewardBoostBasisPoints > BASIS_POINTS_DIVISOR) revert BoostTooHigh();
        _updateRewards(_account);

        rewardBoostsBasisPoints[_account] = _rewardBoostBasisPoints;
        uint256 nextBoostedStakedAmount = Math.mulDiv(
            stakedAmounts[_account],
            BASIS_POINTS_DIVISOR + _rewardBoostBasisPoints,
            BASIS_POINTS_DIVISOR
        );
        boostedTotalSupply =
            boostedTotalSupply -
            boostedStakedAmounts[_account] +
            nextBoostedStakedAmount;
        boostedStakedAmounts[_account] = nextBoostedStakedAmount;

        emit RewardBoostSet(_account, _rewardBoostBasisPoints);
    }

    function _claim(
        address _account,
        address _receiver
    ) private returns (uint256) {
        _updateRewards(_account);

        uint256 tokenAmount = claimableReward[_account];
        claimableReward[_account] = 0;

        if (tokenAmount > 0) {
            // stake for the user
            IERC20(depositToken).approve(address(this), tokenAmount);
            _stake(address(this), _receiver, tokenAmount);
            emit Claim(_account, tokenAmount);
        }

        return tokenAmount;
    }

    function _mint(address _account, uint256 _amount) internal {
        require(
            _account != address(0),
            "RewardTracker: mint to the zero address"
        );

        totalSupply = totalSupply + _amount;
        boostedTotalSupply = boostedTotalSupply + Math.mulDiv(_amount, BASIS_POINTS_DIVISOR + rewardBoostsBasisPoints[_account], BASIS_POINTS_DIVISOR);
        balances[_account] = balances[_account] + _amount;
        uint256 supply = totalSupply;
        uint256 cap = _maxSupply();
        if (supply > cap) {
            revert ERC20ExceededSafeSupply(supply, cap);
        }
        _transferVotingUnits(address(0), _account, _amount);
        emit Transfer(address(0), _account, _amount);
    }

    function _burn(address _account, uint256 _amount) internal {
        require(
            _account != address(0),
            "RewardTracker: burn from the zero address"
        );

        balances[_account] = balances[_account] - _amount; // "RewardTracker: burn amount exceeds balance"
        totalSupply = totalSupply - _amount;
        boostedTotalSupply = boostedTotalSupply - Math.mulDiv(_amount, BASIS_POINTS_DIVISOR + rewardBoostsBasisPoints[_account], BASIS_POINTS_DIVISOR);
        _transferVotingUnits(_account, address(0), _amount);
        emit Transfer(_account, address(0), _amount);
    }

    function _transfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) private {
        require(
            _sender != address(0),
            "RewardTracker: transfer from the zero address"
        );
        require(
            _recipient != address(0),
            "RewardTracker: transfer to the zero address"
        );

        if (inPrivateTransferMode) {
            _validateHandler();
        }

        balances[_sender] = balances[_sender] - _amount; //"RewardTracker: transfer amount exceeds balance");
        balances[_recipient] = balances[_recipient] + _amount;
        _transferVotingUnits(_sender, _recipient, _amount);
        emit Transfer(_sender, _recipient, _amount);
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    ) private {
        require(
            _owner != address(0),
            "RewardTracker: approve from the zero address"
        );
        require(
            _spender != address(0),
            "RewardTracker: approve to the zero address"
        );

        allowances[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);
    }

    /**
     * @dev Returns the voting units of an `account`.
     *
     * WARNING: Overriding this function may compromise the internal vote accounting.
     * `ERC20Votes` assumes tokens map to voting units 1:1 and this is not easy to change.
     */
    function _getVotingUnits(address account) internal view override returns (uint256) {
        return balances[account];
    }

    /**
     * @dev Get number of checkpoints for `account`.
     */
    function numCheckpoints(address account) public view returns (uint32) {
        return _numCheckpoints(account);
    }

    /**
     * @dev Get the `pos`-th checkpoint for `account`.
     */
    function checkpoints(address account, uint32 pos) public view virtual returns (Checkpoints.Checkpoint208 memory) {
        return _checkpoints(account, pos);
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function _validateHandler() private view {
        require(isHandler[msg.sender], "RewardTracker: forbidden");
    }

    function _stake(address _fundingAccount, address _account, uint256 _amount) private {
        require(_amount > 0, "RewardTracker: invalid _amount");

        if (_fundingAccount != address(this)) {
            IERC20(depositToken).safeTransferFrom(_fundingAccount, address(this), _amount);
        }

        _updateRewards(_account);

        stakedAmounts[_account] = stakedAmounts[_account] + (_amount);
        boostedStakedAmounts[_account] = boostedStakedAmounts[_account] + Math.mulDiv(_amount, BASIS_POINTS_DIVISOR + rewardBoostsBasisPoints[_account], BASIS_POINTS_DIVISOR);
        
        depositBalances[_account] = depositBalances[_account] + _amount;
        totalDepositSupply = totalDepositSupply + _amount;

        _mint(_account, _amount);
    }

    function _unstake(address _account, uint256 _amount, address _receiver) private {
        require(_amount > 0, "RewardTracker: invalid _amount");

        _updateRewards(_account);

        uint256 stakedAmount = stakedAmounts[_account];
        require(
            stakedAmounts[_account] >= _amount,
            "RewardTracker: _amount exceeds stakedAmount"
        );

        stakedAmounts[_account] = stakedAmount - _amount;
        boostedStakedAmounts[_account] = boostedStakedAmounts[_account] - Math.mulDiv(_amount, BASIS_POINTS_DIVISOR + rewardBoostsBasisPoints[_account], BASIS_POINTS_DIVISOR);

        uint256 _depositBalance = depositBalances[_account];
        require(_depositBalance >= _amount, "RewardTracker: _amount exceeds depositBalance");
        depositBalances[_account] = _depositBalance - _amount;
        totalDepositSupply = totalDepositSupply - _amount;

        _burn(_account, _amount);
        IERC20(depositToken).safeTransfer(_receiver, _amount);
    }

    function _updateRewards(address _account) private {
        uint256 blockReward = IRewardDistributor(distributor).distribute();

        uint256 _cumulativeRewardPerToken = cumulativeRewardPerToken;
        if (boostedTotalSupply > 0 && blockReward > 0) {
            _cumulativeRewardPerToken =
                _cumulativeRewardPerToken +
                Math.mulDiv(blockReward, PRECISION, boostedTotalSupply);
            cumulativeRewardPerToken = _cumulativeRewardPerToken;
        }

        // cumulativeRewardPerToken can only increase
        // so if cumulativeRewardPerToken is zero, it means there are no rewards yet
        if (_cumulativeRewardPerToken == 0) {
            return;
        }

        if (_account != address(0)) {
            uint256 boostedStakedAmount = boostedStakedAmounts[_account];
            uint256 accountReward = Math.mulDiv(boostedStakedAmount, _cumulativeRewardPerToken - previousCumulatedRewardPerToken[_account], PRECISION);
            uint256 _claimableReward = claimableReward[_account] + accountReward;

            claimableReward[_account] = _claimableReward;
            previousCumulatedRewardPerToken[
                _account
            ] = _cumulativeRewardPerToken;

            if (_claimableReward > 0 && boostedStakedAmounts[_account] > 0) {
                uint256 nextCumulativeReward = cumulativeRewards[_account] +
                    accountReward;

                cumulativeRewards[_account] = nextCumulativeReward;
            }
        }
    }
}
