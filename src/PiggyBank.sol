// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISlopBucket {
    function userInfo(address user) external view returns (uint256 amount, uint256 rewardDebt);
    function pool() external view returns (
        IERC20 lpToken,
        uint256 lastRewardBlock,
        uint256 accPiggyPerShare
    );
}

contract PiggyBank is ERC4626 {
    IERC20 public immutable piggyToken; 
    ISlopBucket public immutable slopBucket;

    struct UserInfo {
        uint256 amount;          // How many PIGGY tokens the user has deposited
        uint256 rewardDebt;      // Reward debt for rewards calculation
    }

    mapping(address => UserInfo) public userInfo;
    uint256 public lastRewardBlock;      
    uint256 public accRewardsPerShare;  

    uint256 public constant REWARDS_PER_BLOCK = 69e17; // 6.9 CRED per block

    constructor(
        IERC20 _piggyToken,
        ISlopBucket _slopBucket
    ) ERC4626(_piggyToken) ERC20("PIGGY BANK", "BANK") {
        piggyToken = _piggyToken;
        slopBucket = _slopBucket;
        lastRewardBlock = block.number;
    }

    // Update pool rewards
    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;
        }

        uint256 totalPiggy = totalAssets();
        if (totalPiggy == 0) {
            lastRewardBlock = block.number;
            return;
        }

        (IERC20 lpToken,,) = slopBucket.pool();
        uint256 totalLPStaked = lpToken.balanceOf(address(slopBucket));
        if (totalLPStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = block.number - lastRewardBlock;
        uint256 reward = multiplier * REWARDS_PER_BLOCK;
        
        accRewardsPerShare += (reward * 1e24) / totalPiggy;
        lastRewardBlock = block.number;
    }

    // View function to see pending CRED rewards for a user
    function pendingRewards(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 _accRewardsPerShare = accRewardsPerShare;
        uint256 totalPiggy = totalAssets();
        
        (IERC20 lpToken,,) = slopBucket.pool();
        uint256 totalLPStaked = lpToken.balanceOf(address(slopBucket));

        if (totalPiggy == 0 || totalLPStaked == 0) {
            return 0;
        }

        if (block.number > lastRewardBlock) {
            uint256 multiplier = block.number - lastRewardBlock;
            uint256 reward = multiplier * REWARDS_PER_BLOCK;
            _accRewardsPerShare += (reward * 1e24) / totalPiggy;
        }

        (uint256 userLPStaked,) = slopBucket.userInfo(_user);
        uint256 lpRatio = (userLPStaked * 1e18) / totalLPStaked;

        uint256 baseReward = (user.amount * _accRewardsPerShare) / 1e24;
        uint256 pendingReward = baseReward - user.rewardDebt;
        return (pendingReward * lpRatio) / 1e18;
    }

    // Convert assets to shares 1:1
    function convertToShares(uint256 assets) public view virtual override returns (uint256) {
        return assets;
    }

    // Convert shares to assets 1:1
    function convertToAssets(uint256 shares) public view virtual override returns (uint256) {
        return shares;
    }

    // Deposit PIGGY tokens to get PIGGY BANK shares for CRED rewards
    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        updatePool();  
        
        UserInfo storage user = userInfo[receiver];
        uint256 shares = super.deposit(assets, receiver);
        
        user.amount += assets;
        user.rewardDebt = (user.amount * accRewardsPerShare) / 1e24; 
        
        return shares;
    }

    // Redeem PIGGY BANK shares to get back PIGGY tokens
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override returns (uint256) {
        updatePool();  
        
        UserInfo storage user = userInfo[owner];

        uint256 pending = (user.amount * accRewardsPerShare) / 1e24 - user.rewardDebt;
        
        uint256 assets = super.redeem(shares, receiver, owner);
        
        user.amount -= assets;
        user.rewardDebt = (user.amount * accRewardsPerShare) / 1e24; 
        
        if (pending > 0) {
            piggyToken.transfer(owner, pending);
        }
        
        return assets;
    }
}
