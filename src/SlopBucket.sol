// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SlopBucket is Ownable {
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has staked
        uint256 rewardDebt; // Reward debt
    }

    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract
        uint256 allocPoint; // Allocation points for the pool
        uint256 lastRewardBlock; // Last block number when rewards were distributed
        uint256 accPiggyPerShare; // Accumulated PIGGYs per share, times 1e12
    }

    IERC20 public piggy; // The PIGGY token
    uint256 public piggyPerBlock; // Tokens distributed per block
    uint256 public totalAllocPoint; // Total allocation points
    uint256 public startBlock; // Block number when rewards start

    PoolInfo public pool;
    mapping(address => UserInfo) public userInfo;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event ClaimRewards(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor(
        IERC20 _piggy,
        IERC20 _lpToken,
        uint256 _piggyPerBlock,
        uint256 _startBlock
    ) Ownable(msg.sender) {
        piggy = _piggy;
        piggyPerBlock = _piggyPerBlock;
        startBlock = _startBlock;

        // Initialize the pool
        pool = PoolInfo({
            lpToken: _lpToken,
            allocPoint: 1000, // Full allocation to this pool
            lastRewardBlock: _startBlock,
            accPiggyPerShare: 0
        });

        totalAllocPoint = 1000;
    }

    // Update pool rewards
    function updatePool() public {
        if (block.number <= pool.lastRewardBlock) {
            return;
        }

        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = block.number - pool.lastRewardBlock;
        uint256 piggyReward = (multiplier * piggyPerBlock * pool.allocPoint) / totalAllocPoint;
        pool.accPiggyPerShare += (piggyReward * 1e12) / lpSupply;
        pool.lastRewardBlock = block.number;
    }

    // View function to see pending PIGGY rewards for a user
    function pendingRewards(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 accPiggyPerShare = pool.accPiggyPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));

        if (block.number > pool.lastRewardBlock && lpSupply > 0) {
            uint256 multiplier = block.number - pool.lastRewardBlock;
            uint256 piggyReward = (multiplier * piggyPerBlock * pool.allocPoint) / totalAllocPoint;
            accPiggyPerShare += (piggyReward * 1e12) / lpSupply;
        }

        return (user.amount * accPiggyPerShare) / 1e12 - user.rewardDebt;
    }

    // Deposit LP tokens for PIGGY rewards
    function deposit(uint256 _amount) external {
        UserInfo storage user = userInfo[msg.sender];
        updatePool();

        if (user.amount > 0) {
            uint256 pending = (user.amount * pool.accPiggyPerShare) / 1e12 - user.rewardDebt;
            if (pending > 0) {
                piggy.transfer(msg.sender, pending);
            }
        }

        if (_amount > 0) {
            pool.lpToken.transferFrom(msg.sender, address(this), _amount);
            user.amount += _amount;
        }

        user.rewardDebt = (user.amount * pool.accPiggyPerShare) / 1e12;
        emit Deposit(msg.sender, _amount);
    }

    // Withdraw LP tokens and claim PIGGY rewards
    function withdraw(uint256 _amount) external {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "Withdraw amount exceeds balance");
        updatePool();

        uint256 pending = (user.amount * pool.accPiggyPerShare) / 1e12 - user.rewardDebt;
        if (pending > 0) {
            piggy.transfer(msg.sender, pending);
        }

        if (_amount > 0) {
            user.amount -= _amount;
            pool.lpToken.transfer(msg.sender, _amount);
        }

        user.rewardDebt = (user.amount * pool.accPiggyPerShare) / 1e12;
        emit Withdraw(msg.sender, _amount);
    }

    // Claim only PIGGY rewards
    function claimRewards() external {
        UserInfo storage user = userInfo[msg.sender];
        updatePool();

        uint256 pending = (user.amount * pool.accPiggyPerShare) / 1e12 - user.rewardDebt;
        require(pending > 0, "No rewards to claim");

        piggy.transfer(msg.sender, pending);
        user.rewardDebt = (user.amount * pool.accPiggyPerShare) / 1e12;
        emit ClaimRewards(msg.sender, pending);
    }

    // Emergency withdraw without rewards
    function emergencyWithdraw() external {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amount = user.amount;

        user.amount = 0;
        user.rewardDebt = 0;

        if (amount > 0) {
            pool.lpToken.transfer(msg.sender, amount);
        }

        emit EmergencyWithdraw(msg.sender, amount);
    }
}
