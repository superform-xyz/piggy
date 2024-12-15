// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISlopBucket {
    function userInfo(address user) external view returns (uint256 amount, uint256 rewardDebt);
}

contract PiggyVault is ERC4626 {
    IERC20 public immutable piggyToken; // PIGGY token
    ISlopBucket public immutable slopBucket; // SlopBucket contract

    struct UserInfo {
        uint256 lastUpdated;
        uint256 accumulatedCRED;
    }

    mapping(address => UserInfo) public userInfo;

    uint256 public credRate;       // CRED points earned per second per staked PIGGY
    uint256 public multiplierRate; // Multiplier for LP stakers, scaled by 1e18

    constructor(
        IERC20 _piggyToken,
        ISlopBucket _slopBucket,
        uint256 _credRate,
        uint256 _multiplierRate
    ) ERC4626(_piggyToken) {
        piggyToken = _piggyToken;
        slopBucket = _slopBucket;
        credRate = _credRate;
        multiplierRate = _multiplierRate;
    }

    /// @notice Update CRED points for a user
    function updateCRED(address user) public {
        UserInfo storage userDetail = userInfo[user];

        if (userDetail.lastUpdated > 0) {
            uint256 stakedBalance = balanceOf(user);
            uint256 timeElapsed = block.timestamp - userDetail.lastUpdated;

            if (stakedBalance > 0) {
                (uint256 lpBalance, ) = slopBucket.userInfo(user);
                uint256 multiplier = getMultiplier(stakedBalance, lpBalance);
                userDetail.accumulatedCRED +=
                    (stakedBalance * credRate * timeElapsed * multiplier) / 1e18;
            }
        }

        userDetail.lastUpdated = block.timestamp;
    }

    /// @notice Override deposit to update user rewards
    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        updateCRED(receiver);
        return super.deposit(assets, receiver);
    }

    /// @notice Override withdraw to update user rewards
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
        updateCRED(owner);
        return super.withdraw(assets, receiver, owner);
    }

    /// @notice View accumulated CRED points for a user
    function viewCRED(address user) external view returns (uint256) {
        UserInfo storage userDetail = userInfo[user];
        uint256 stakedBalance = balanceOf(user);
        (uint256 lpBalance, ) = slopBucket.userInfo(user);

        uint256 timeElapsed = block.timestamp - userDetail.lastUpdated;
        uint256 multiplier = getMultiplier(stakedBalance, lpBalance);

        return
            userDetail.accumulatedCRED +
            ((stakedBalance * credRate * timeElapsed * multiplier) / 1e18);
    }

    /// @notice Get the multiplier based on LP and PIGGY balances
    function getMultiplier(uint256 piggyStaked, uint256 lpStaked) public view returns (uint256) {
        if (lpStaked == 0) {
            return 1e18; // No boost without LP balance
        }
        uint256 lpProportion = (lpStaked * 1e18) / piggyStaked;
        uint256 boost = (lpProportion * multiplierRate) / 1e18;
        return 1e18 + boost; // Base multiplier (1x) + LP boost
    }

    /// @notice Set the CRED earning rate (admin function)
    function setCredRate(uint256 _credRate) external onlyOwner {
        credRate = _credRate;
    }

    /// @notice Set the multiplier rate (admin function)
    function setMultiplierRate(uint256 _multiplierRate) external onlyOwner {
        multiplierRate = _multiplierRate;
    }
}
