// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SlopBucket.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PiggyToken is ERC20 {
    constructor() ERC20("Piggy Token", "PIGGY") {}
}

contract LPToken is ERC20 {
    constructor() ERC20("LP Token", "LPT") {}
}

contract SlopBucketTest is Test {
    ERC20 public piggy;
    ERC20 public lpToken;
    SlopBucket public slopBucket;

    address public owner;
    address public user1;
    address public user2;

    uint256 public constant TOTAL_SUPPLY = 69_000_000_000 * 10 ** 18;
    uint256 public constant REWARD_SUPPLY = 6_900_000_000 * 10 ** 18;
    uint256 public constant LP_SUPPLY = 1_000 * 10 ** 18; // Total LP tokens for users
    uint256 public constant PIGGY_PER_BLOCK = 1331.4 * 10 ** 18; // ~6.9B over 4 months (5,184,000 blocks)
    uint256 public constant START_BLOCK = 100;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        // Deploy Piggy and LP token contracts
        piggy = new PiggyToken();
        lpToken = new LPToken();

        // Deploy SlopBucket contract
        slopBucket = new SlopBucket(IERC20(address(piggy)), IERC20(address(lpToken)), PIGGY_PER_BLOCK, START_BLOCK);

        // Mint tokens and set up initial balances
        deal(address(piggy), owner, TOTAL_SUPPLY);
        deal(address(lpToken), user1, 1_000 * 10 ** 18);
        deal(address(lpToken), user2, 1_000 * 10 ** 18);

        // Transfer rewards to SlopBucket
        piggy.transfer(address(slopBucket), REWARD_SUPPLY);
    }

    function test_Constructor() public {
        assertEq(address(slopBucket.piggy()), address(piggy));
        assertEq(slopBucket.piggyPerBlock(), PIGGY_PER_BLOCK);
        assertEq(slopBucket.startBlock(), START_BLOCK);
    }

    function test_DepositAndRewards() public {
        vm.roll(START_BLOCK);

        // User1 deposits LP tokens
        vm.startPrank(user1);
        lpToken.approve(address(slopBucket), 500 * 10 ** 18);
        slopBucket.deposit(500 * 10 ** 18);
        vm.stopPrank();

        // Simulate some blocks passing
        vm.roll(START_BLOCK + 100);

        // Check rewards for User1
        uint256 pendingReward = slopBucket.pendingRewards(user1);
        assertGt(pendingReward, 0);

        // User1 withdraws LP tokens and claims rewards
        vm.startPrank(user1);
        slopBucket.withdraw(500 * 10 ** 18);
        vm.stopPrank();

        assertEq(lpToken.balanceOf(user1), 1_000 * 10 ** 18); // LP balance restored
        assertGt(piggy.balanceOf(user1), 0); // Rewards received
    }

    function test_RewardDistribution() public {
        vm.roll(START_BLOCK);

        // User1 deposits LP tokens
        vm.startPrank(user1);
        lpToken.approve(address(slopBucket), 500 * 10 ** 18);
        slopBucket.deposit(500 * 10 ** 18);
        vm.stopPrank();

        // Simulate some blocks
        vm.roll(START_BLOCK + 50);

        // User2 deposits LP tokens
        vm.startPrank(user2);
        lpToken.approve(address(slopBucket), 500 * 10 ** 18);
        slopBucket.deposit(500 * 10 ** 18);
        vm.stopPrank();

        // Simulate additional blocks
        vm.roll(START_BLOCK + 100);

        // Check rewards
        uint256 rewardUser1 = slopBucket.pendingRewards(user1);
        uint256 rewardUser2 = slopBucket.pendingRewards(user2);

        assertGt(rewardUser1, rewardUser2); // User1 has more rewards as they deposited earlier
    }

    function test_EmergencyWithdraw() public {
        vm.startPrank(user1);

        // User1 deposits LP tokens
        lpToken.approve(address(slopBucket), 500 * 10 ** 18);
        slopBucket.deposit(500 * 10 ** 18);

        // User1 calls emergencyWithdraw
        slopBucket.emergencyWithdraw();

        // Verify LP tokens are returned without rewards
        assertEq(lpToken.balanceOf(user1), 1_000 * 10 ** 18);
        assertEq(piggy.balanceOf(user1), 0);

        vm.stopPrank();
    }

    function testFail_WithdrawMoreThanDeposited() public {
        vm.startPrank(user1);

        // User1 deposits LP tokens
        lpToken.approve(address(slopBucket), 500 * 10 ** 18);
        slopBucket.deposit(500 * 10 ** 18);

        // Attempt to withdraw more than deposited
        slopBucket.withdraw(600 * 10 ** 18);

        vm.stopPrank();
    }

    function test_ViewPendingRewards() public {
        vm.roll(START_BLOCK);

        // User1 deposits LP tokens
        vm.startPrank(user1);
        lpToken.approve(address(slopBucket), 500 * 10 ** 18);
        slopBucket.deposit(500 * 10 ** 18);
        vm.stopPrank();

        // Simulate some blocks passing
        vm.roll(START_BLOCK + 50);

        // Check pending rewards
        uint256 pendingReward = slopBucket.pendingRewards(user1);
        assertGt(pendingReward, 0);
    }

    function test_ClaimRewards() public {
    // User1 deposits LP tokens
    vm.startPrank(user1);
    lpToken.approve(address(slopBucket), LP_SUPPLY);
    slopBucket.deposit(500 * 10 ** 18); // Deposit 500 LP tokens
    vm.stopPrank();

    // Move blocks to accumulate rewards
    vm.roll(START_BLOCK + 10);

    // User1 claims rewards
    vm.startPrank(user1);
    uint256 pendingRewards = slopBucket.pendingRewards(user1);
    assertGt(pendingRewards, 0, "Rewards should be greater than 0");

    uint256 piggyBalanceBefore = piggy.balanceOf(user1);
    slopBucket.claimRewards();
    uint256 piggyBalanceAfter = piggy.balanceOf(user1);

    // Verify rewards are received
    assertEq(piggyBalanceAfter - piggyBalanceBefore, pendingRewards, "Claimed rewards should match pending rewards");

    // Destructure PoolInfo to get accPiggyPerShare
    (, , , uint256 accPiggyPerShare) = slopBucket.pool();

    // Destructure UserInfo to get rewardDebt
    (, uint256 rewardDebt) = slopBucket.userInfo(user1);

    // Verify rewardDebt is updated
    uint256 expectedRewardDebt = (500 * 10 ** 18 * accPiggyPerShare) / 1e12;
    assertEq(rewardDebt, expectedRewardDebt, "Reward debt should be updated correctly");
    vm.stopPrank();

    // Verify LP balance remains the same
    assertEq(lpToken.balanceOf(user1), LP_SUPPLY - 500 * 10 ** 18, "LP balance should remain unchanged");
}


    function test_ClaimRewards_NoPendingRewards() public {
        // User1 deposits LP tokens
        vm.startPrank(user1);
        lpToken.approve(address(slopBucket), LP_SUPPLY);
        slopBucket.deposit(500 * 10 ** 18); // Deposit 500 LP tokens
        slopBucket.claimRewards(); // Immediately claim rewards
        vm.stopPrank();

        // Verify no rewards are available to claim again
        vm.startPrank(user1);
        vm.expectRevert("No rewards to claim");
        slopBucket.claimRewards();
        vm.stopPrank();
    }
}
