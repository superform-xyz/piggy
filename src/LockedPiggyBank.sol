// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LockedPiggyBank is ERC4626 {
    mapping(address => uint256) public lockEndTime;
    uint256 constant LOCK_DURATION = 69 days;

    event Locked(address indexed user, uint256 amount, uint256 unlockTime);

    error TokensLocked(uint256 unlockTime);
    error ZeroDeposit();

    constructor(
        IERC20 _piggyToken
    ) ERC4626(_piggyToken) ERC20("PIGGY BANK", "BANK") {}

    // View function to check if a user's tokens are locked
    function isLocked(address user) public view returns (bool) {
        return block.timestamp < lockEndTime[user];
    }

    // View function to check remaining lock time
    function remainingLockTime(address user) public view returns (uint256) {
        if (!isLocked(user)) return 0;
        return lockEndTime[user] - block.timestamp;
    }

    // Convert assets to shares 1:1
    function convertToShares(uint256 assets) public view virtual override returns (uint256) {
        return assets;
    }

    // Convert shares to assets 1:1
    function convertToAssets(uint256 shares) public view virtual override returns (uint256) {
        return shares;
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        if (assets == 0) revert ZeroDeposit();
        
        uint256 unlockTime = block.timestamp + LOCK_DURATION;
        lockEndTime[msg.sender] = unlockTime;
        
        uint256 shares = super.deposit(assets, receiver);
        
        emit Locked(msg.sender, assets, unlockTime);
        return shares;
    }

    function mint(uint256 shares, address receiver) public override returns (uint256) {
        if (shares == 0) revert ZeroDeposit();
        
        uint256 unlockTime = block.timestamp + LOCK_DURATION;
        lockEndTime[msg.sender] = unlockTime;
        
        uint256 assets = super.mint(shares, receiver);
        
        emit Locked(msg.sender, assets, unlockTime);
        return assets;
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override returns (uint256) {
        if (isLocked(msg.sender)) {
            revert TokensLocked(lockEndTime[msg.sender]);
        }
        return super.redeem(shares, receiver, owner);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256) {
        if (isLocked(msg.sender)) {
            revert TokensLocked(lockEndTime[msg.sender]);
        }
        return super.withdraw(assets, receiver, owner);
    }

    // Prevent maxDeposit/maxMint from being limited by the vault
    function maxDeposit(address) public pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public pure override returns (uint256) {
        return type(uint256).max;
    }

    // Prevent withdrawals/redemptions when locked
    function maxWithdraw(address owner) public view override returns (uint256) {
        return isLocked(msg.sender) ? 0 : super.maxWithdraw(owner);
    }

    function maxRedeem(address owner) public view override returns (uint256) {
        return isLocked(msg.sender) ? 0 : super.maxRedeem(owner);
    }

    // Preview functions with early reverts
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        if (isLocked(msg.sender)) {
            revert TokensLocked(lockEndTime[msg.sender]);
        }
        return super.previewWithdraw(assets);
    }

    function previewRedeem(uint256 shares) public view override returns (uint256) {
        if (isLocked(msg.sender)) {
            revert TokensLocked(lockEndTime[msg.sender]);
        }
        return super.previewRedeem(shares);
    }
}
