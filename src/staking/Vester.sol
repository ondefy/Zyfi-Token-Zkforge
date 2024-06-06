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

    string public name;
    string public symbol;
    uint8 public decimals = 18;

    uint256 public vestingDuration;

    address public esToken;
    address public claimableToken;

    address public override rewardTracker;

    uint256 public override totalSupply;

    bool public hasMaxVestableAmount;

    mapping (address => uint256) public balances;
    mapping (address => uint256) public override cumulativeClaimAmounts;
    mapping (address => uint256) public override claimedAmounts;
    mapping (address => uint256) public lastVestingTimes;

    mapping (address => uint256) public override transferredCumulativeRewards;
    mapping (address => uint256) public override cumulativeRewardDeductions;
    mapping (address => uint256) public override bonusRewards;

    mapping (address => bool) public isHandler;
    mapping (address => bool) public isWhitelistedSender;
    mapping (address => mapping (address => uint256)) public allowances;

    event Claim(address receiver, uint256 amount);
    event Deposit(address account, uint256 amount);
    event Withdraw(address account, uint256 claimedAmount, uint256 balance);

    modifier enforceIsWhitelistedSender() {
        require(isWhitelistedSender[msg.sender], "Only whitelisted senders");
        _;
    }

    constructor (
        string memory _name,
        string memory _symbol,
        uint256 _vestingDuration,
        address _esToken,
        address _claimableToken,
        address _rewardTracker
    ) {
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
    }

    function setIsWhitelistedSender(address _address, bool _isActive) external onlyGov {
        isWhitelistedSender[_address] = _isActive;
    }

    function setHasMaxVestableAmount(bool _hasMaxVestableAmount) external onlyGov {
        hasMaxVestableAmount = _hasMaxVestableAmount;
    }

    function deposit(uint256 _amount) external nonReentrant {
        _deposit(msg.sender, _amount);
    }

    function depositForAccount(address _account, uint256 _amount) external nonReentrant {
        _validateHandler();
        _deposit(_account, _amount);
    }

    function claim() external nonReentrant returns (uint256) {
        return _claim(msg.sender, msg.sender);
    }

    function claimForAccount(address _account, address _receiver) external override nonReentrant returns (uint256) {
        _validateHandler();
        return _claim(_account, _receiver);
    }

    // to help users who accidentally send their tokens to this contract
    function rescueFunds(address _token, address _account, uint256 _amount) external onlyGov {
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

        IERC20(esToken).safeTransfer(_receiver, balance);
        _burn(account, balance);

        delete cumulativeClaimAmounts[account];
        delete claimedAmounts[account];
        delete lastVestingTimes[account];

        emit Withdraw(account, claimedAmount, balance);
    }

    function transferStakeValues(address _sender, address _receiver) external override nonReentrant {
        _validateHandler();

        uint256 transferredCumulativeReward = transferredCumulativeRewards[_sender];
        uint256 cumulativeReward = IRewardTracker(rewardTracker).cumulativeRewards(_sender);

        transferredCumulativeRewards[_receiver] = transferredCumulativeReward + cumulativeReward;
        cumulativeRewardDeductions[_sender] = cumulativeReward;
        transferredCumulativeRewards[_sender] = 0;

        bonusRewards[_receiver] = bonusRewards[_sender];
        bonusRewards[_sender] = 0;
    }

    function setTransferredCumulativeRewards(address _account, uint256 _amount) external override nonReentrant {
        _validateHandler();
        transferredCumulativeRewards[_account] = _amount;
    }

    function setCumulativeRewardDeductions(address _account, uint256 _amount) external override nonReentrant {
        _validateHandler();
        cumulativeRewardDeductions[_account] = _amount;
    }

    function setBonusRewards(address _account, uint256 _amount) external override nonReentrant {
        _validateHandler();
        bonusRewards[_account] = _amount;
    }

    function claimable(address _account) public override view returns (uint256) {
        uint256 amount = cumulativeClaimAmounts[_account] - claimedAmounts[_account];
        uint256 nextClaimable = _getNextClaimableAmount(_account);
        return amount + nextClaimable;
    }

    function getMaxVestableAmount(address _account) public override view returns (uint256) {
        if (!hasRewardTracker()) { return 0; }

        uint256 transferredCumulativeReward = transferredCumulativeRewards[_account];
        uint256 bonusReward = bonusRewards[_account];
        uint256 cumulativeReward = IRewardTracker(rewardTracker).cumulativeRewards(_account);
        uint256 maxVestableAmount = cumulativeReward + transferredCumulativeReward + bonusReward;

        uint256 cumulativeRewardDeduction = cumulativeRewardDeductions[_account];

        if (maxVestableAmount < cumulativeRewardDeduction) {
            return 0;
        }

        return maxVestableAmount - cumulativeRewardDeduction;
    }

    function hasRewardTracker() public view returns (bool) {
        return rewardTracker != address(0);
    }

    function getTotalVested(address _account) public view returns (uint256) {
        return balances[_account] + cumulativeClaimAmounts[_account];
    }

    function balanceOf(address _account) public view override returns (uint256) {
        return balances[_account];
    }

    function allowance(address _owner, address _spender) public view virtual override returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount) public virtual override enforceIsWhitelistedSender returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transfer(address _recipient, uint256 _amount) public virtual override enforceIsWhitelistedSender returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public virtual override enforceIsWhitelistedSender returns (bool) {
        uint256 _allowance = allowances[_sender][msg.sender];
        require(_amount <= _allowance, "Transfer amount exceeds allowance");
        uint256 _nextAllowance = _allowance - _amount;
        _approve(_sender, msg.sender, _nextAllowance);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function getVestedAmount(address _account) public override view returns (uint256) {
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

        balances[_account] = balances[_account] - _amount;// "Vester: burn amount exceeds balance"
        totalSupply = totalSupply - _amount;

        emit Transfer(_account, address(0), _amount);
    }

    function _deposit(address _account, uint256 _amount) private {
        require(_amount > 0, "Vester: invalid _amount");

        _updateVesting(_account);

        IERC20(esToken).safeTransferFrom(_account, address(this), _amount);

        _mint(_account, _amount);

        if (hasMaxVestableAmount) {
            uint256 maxAmount = getMaxVestableAmount(_account);
            require(getTotalVested(_account) <= maxAmount, "Vester: max vestable amount exceeded");
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
        cumulativeClaimAmounts[_account] = cumulativeClaimAmounts[_account] + amount;

        IERC20Burnable(esToken).burnFrom(address(this), amount);
    }

    function _getNextClaimableAmount(address _account) private view returns (uint256) {
        uint256 timeDiff = block.timestamp - lastVestingTimes[_account];

        uint256 balance = balances[_account];
        if (balance == 0) { return 0; }

        uint256 vestedAmount = getVestedAmount(_account);
        uint256 claimableAmount = Math.mulDiv(vestedAmount, timeDiff, vestingDuration);

        if (claimableAmount < balance) {
            return claimableAmount;
        }

        return balance;
    }

    function _claim(address _account, address _receiver) private returns (uint256) {
        _updateVesting(_account);
        uint256 amount = claimable(_account);
        claimedAmounts[_account] = claimedAmounts[_account] + amount;
        IERC20(claimableToken).safeTransfer(_receiver, amount);
        emit Claim(_account, amount);
        return amount;
    }

    function _validateHandler() private view {
        require(isHandler[msg.sender], "Vester: forbidden");
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) private {
        require(_sender != address(0), "Transfer from the zero address");
        require(_recipient != address(0), "Transfer to the zero address");
        uint256 _balance = balances[_sender];
        require(_amount <= _balance, "Transfer amount exceeds balance");
        
        balances[_sender] = _balance - _amount;
        balances[_recipient] = balances[_recipient] + _amount;

        emit Transfer(_sender, _recipient,_amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) private {
        require(_owner != address(0), "Approve from the zero address");
        require(_spender != address(0), "Approve to the zero address");

        allowances[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);
    }
}
