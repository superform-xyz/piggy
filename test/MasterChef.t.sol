// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/MasterChef.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PiggyToken is ERC20 {
    constructor() ERC20("Piggy Token", "PIGGY") {}
}

contract LPToken is ERC20 {
    constructor() ERC20("LP Token", "LPT") {}
}

contract MasterChefTest is Test {
    ERC20 public piggy;
    ERC20 public lpToken;
    MasterChef public masterChef;

    address public owner;
    address public user1;
    address public user2;

    uint256 public constant TOTAL_SUPPLY = 69_000_000_000 * 10 ** 18;
    uint256 public constant REWARD_SUPPLY = 6_900_000_000 * 10 ** 18;
    uint256 public constant PIGGY_PER_BLOCK = 1331.4 * 10 ** 18; // ~6.9B over 4 months (5,184,000 blocks)
    uint256 public constant START_BLOCK = 100;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        // Deploy Piggy and LP token contracts
        piggy = new PiggyToken();
        lpToken = new LPToken();

        // Deploy MasterChef contract
        masterChef = new MasterChef(IERC20(address(piggy)), IERC20(address(lpToken)), PIGGY_PER_BLOCK, START_BLOCK);

        // Mint tokens and set up initial balances
        deal(address(piggy), owner, TOTAL_SUPPLY);
        deal(address(lpToken), user1, 1_000 * 10 ** 18);
        deal(address(lpToken), user2, 1_000 * 10 ** 18);

        // Transfer rewards to MasterChef
        piggy.transfer(address(masterChef), REWARD_SUPPLY);
    }

    function test_Constructor() public {
        assertEq(address(masterChef.piggy()), address(piggy));
        assertEq(masterChef.piggyPerBlock(), PIGGY_PER_BLOCK);
        assertEq(masterChef.startBlock(), START_BLOCK);
    }

    function test_DepositAndRewards() public {
        vm.roll(START_BLOCK);

        // User1 deposits LP tokens
        vm.startPrank(user1);
        lpToken.approve(address(masterChef), 500 * 10 ** 18);
        masterChef.deposit(500 * 10 ** 18);
        vm.stopPrank();

        // Simulate some blocks passing
        vm.roll(START_BLOCK + 100);

        // Check rewards for User1
        uint256 pendingReward = masterChef.pendingRewards(user1);
        assertGt(pendingReward, 0);

        // User1 withdraws LP tokens and claims rewards
        vm.startPrank(user1);
        masterChef.withdraw(500 * 10 ** 18);
        vm.stopPrank();

        assertEq(lpToken.balanceOf(user1), 1_000 * 10 ** 18); // LP balance restored
        assertGt(piggy.balanceOf(user1), 0); // Rewards received
    }

    function test_RewardDistribution() public {
        vm.roll(START_BLOCK);

        // User1 deposits LP tokens
        vm.startPrank(user1);
        lpToken.approve(address(masterChef), 500 * 10 ** 18);
        masterChef.deposit(500 * 10 ** 18);
        vm.stopPrank();

        // Simulate some blocks
        vm.roll(START_BLOCK + 50);

        // User2 deposits LP tokens
        vm.startPrank(user2);
        lpToken.approve(address(masterChef), 500 * 10 ** 18);
        masterChef.deposit(500 * 10 ** 18);
        vm.stopPrank();

        // Simulate additional blocks
        vm.roll(START_BLOCK + 100);

        // Check rewards
        uint256 rewardUser1 = masterChef.pendingRewards(user1);
        uint256 rewardUser2 = masterChef.pendingRewards(user2);

        assertGt(rewardUser1, rewardUser2); // User1 has more rewards as they deposited earlier
    }

    function test_EmergencyWithdraw() public {
        vm.startPrank(user1);

        // User1 deposits LP tokens
        lpToken.approve(address(masterChef), 500 * 10 ** 18);
        masterChef.deposit(500 * 10 ** 18);

        // User1 calls emergencyWithdraw
        masterChef.emergencyWithdraw();

        // Verify LP tokens are returned without rewards
        assertEq(lpToken.balanceOf(user1), 1_000 * 10 ** 18);
        assertEq(piggy.balanceOf(user1), 0);

        vm.stopPrank();
    }

    function testFail_WithdrawMoreThanDeposited() public {
        vm.startPrank(user1);

        // User1 deposits LP tokens
        lpToken.approve(address(masterChef), 500 * 10 ** 18);
        masterChef.deposit(500 * 10 ** 18);

        // Attempt to withdraw more than deposited
        masterChef.withdraw(600 * 10 ** 18);

        vm.stopPrank();
    }

    function test_ViewPendingRewards() public {
        vm.roll(START_BLOCK);

        // User1 deposits LP tokens
        vm.startPrank(user1);
        lpToken.approve(address(masterChef), 500 * 10 ** 18);
        masterChef.deposit(500 * 10 ** 18);
        vm.stopPrank();

        // Simulate some blocks passing
        vm.roll(START_BLOCK + 50);

        // Check pending rewards
        uint256 pendingReward = masterChef.pendingRewards(user1);
        assertGt(pendingReward, 0);
    }
}
