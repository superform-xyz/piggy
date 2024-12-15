// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PiggyBank.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/console.sol";

contract PiggyToken is ERC20 {
    constructor() ERC20("Piggy Token", "PIGGY") { }
}

contract MockSlopBucket {
    IERC20 public lpToken;
    mapping(address => UserInfo) public userInfo;
    
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }
    
    struct PoolInfo {
        IERC20 lpToken;
        uint256 lastRewardBlock;
        uint256 accPiggyPerShare;
    }

    constructor(IERC20 _lpToken) {
        lpToken = _lpToken;
    }

    function setUserInfo(address user, uint256 amount) external {
        userInfo[user].amount = amount;
    }

    function pool() external view returns (IERC20, uint256, uint256) {
        return (lpToken, 0, 0);
    }
}

contract LPToken is ERC20 {
    constructor() ERC20("LP Token", "LPT") { }
}

contract PiggyBankTest is Test {
    PiggyToken public piggy;
    LPToken public lpToken;
    MockSlopBucket public slopBucket;
    PiggyBank public piggyBank;

    address public owner;
    address public user1;
    address public user2;

    uint256 public constant INITIAL_PIGGY = 1000 * 1e18;
    uint256 public constant INITIAL_LP = 100 * 1e18;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        // Deploy tokens
        piggy = new PiggyToken();
        lpToken = new LPToken();
        
        // Deploy mock SlopBucket
        slopBucket = new MockSlopBucket(IERC20(address(lpToken)));
        
        // Deploy PiggyBank
        piggyBank = new PiggyBank(IERC20(address(piggy)), ISlopBucket(address(slopBucket)));

        // Setup initial balances
        deal(address(piggy), user1, INITIAL_PIGGY);
        deal(address(piggy), user2, INITIAL_PIGGY);
        deal(address(lpToken), address(slopBucket), INITIAL_LP);
    }

    function test_Constructor() public {
        assertEq(address(piggyBank.piggyToken()), address(piggy));
        assertEq(address(piggyBank.slopBucket()), address(slopBucket));
    }

    function test_Deposit() public {
        uint256 depositAmount = 100 * 1e18;
        
        vm.startPrank(user1);
        piggy.approve(address(piggyBank), depositAmount);
        uint256 shares = piggyBank.deposit(depositAmount, user1);
        vm.stopPrank();

        assertEq(shares, depositAmount);
        assertEq(piggyBank.balanceOf(user1), depositAmount);
        assertEq(piggy.balanceOf(address(piggyBank)), depositAmount);
    }

    function test_Redeem() public {
        uint256 depositAmount = 100 * 1e18;
        
        vm.startPrank(user1);
        piggy.approve(address(piggyBank), depositAmount);
        piggyBank.deposit(depositAmount, user1);
        
        uint256 assets = piggyBank.redeem(depositAmount, user1, user1);
        vm.stopPrank();

        assertEq(assets, depositAmount);
        assertEq(piggyBank.balanceOf(user1), 0);
        assertEq(piggy.balanceOf(user1), INITIAL_PIGGY);
    }

    function test_PendingRewards() public {
        uint256 depositAmount = 100 * 1e18;
        
        // User1 deposits PIGGY
        vm.startPrank(user1);
        piggy.approve(address(piggyBank), depositAmount);
        piggyBank.deposit(depositAmount, user1);
        vm.stopPrank();

        // Set user1's LP stake in SlopBucket
        slopBucket.setUserInfo(user1, 50 * 1e18);

        // Move forward some blocks
        vm.roll(block.number + 100);

        // Update pool
        piggyBank.updatePool();

        // Check pending rewards
        uint256 pendingRewards = piggyBank.pendingRewards(user1);
        assertGt(pendingRewards, 0);
    }

    function test_UpdatePool() public {
        uint256 depositAmount = 100 * 1e18;
        
        // User1 deposits PIGGY
        vm.startPrank(user1);
        piggy.approve(address(piggyBank), depositAmount);
        piggyBank.deposit(depositAmount, user1);
        vm.stopPrank();

        uint256 initialLastRewardBlock = piggyBank.lastRewardBlock();
        
        // Move forward some blocks
        vm.roll(block.number + 100);
        
        piggyBank.updatePool();
        
        assertGt(piggyBank.lastRewardBlock(), initialLastRewardBlock);
        assertGt(piggyBank.accRewardsPerShare(), 0);
    }

    function test_MultipleUsersRewards() public {
        uint256 depositAmount = 100 * 1e18;
        
        // Set initial block
        vm.roll(1);
        
        // User1 deposits
        vm.startPrank(user1);
        piggy.approve(address(piggyBank), depositAmount);
        piggyBank.deposit(depositAmount, user1);
        vm.stopPrank();

        // Set user1's LP stake
        slopBucket.setUserInfo(user1, 50 * 1e18);

        console.log("Initial block:", block.number);
        console.log("Initial total assets:", piggyBank.totalAssets());
        
        // Move forward
        vm.roll(block.number + 50);
        console.log("Block after first 50:", block.number);
        
        // Important: Update pool before user2 enters
        piggyBank.updatePool();
        uint256 user1FirstRewards = piggyBank.pendingRewards(user1);
        console.log("User1 pending after first 50:", user1FirstRewards);

        // User2 deposits
        vm.startPrank(user2);
        piggy.approve(address(piggyBank), depositAmount);
        piggyBank.deposit(depositAmount, user2);
        vm.stopPrank();

        // Set user2's LP stake
        slopBucket.setUserInfo(user2, 50 * 1e18);

        console.log("Total assets after user2 deposit:", piggyBank.totalAssets());

        // Move forward more blocks
        vm.roll(block.number + 50);
        console.log("Block after second 50:", block.number);

        // Update pool
        piggyBank.updatePool();

        uint256 rewards1 = piggyBank.pendingRewards(user1);
        uint256 rewards2 = piggyBank.pendingRewards(user2);

        console.log("Final User1 rewards:", rewards1);
        console.log("Final User2 rewards:", rewards2);
        console.log("Difference:", rewards1 > rewards2 ? rewards1 - rewards2 : rewards2 - rewards1);
        console.log("AccRewardsPerShare:", piggyBank.accRewardsPerShare());

        // User1 should have more rewards as they were in longer
        assertGt(rewards1, rewards2);
    }
}
