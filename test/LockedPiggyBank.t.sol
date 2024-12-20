// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/LockedPiggyBank.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PiggyToken is ERC20 {
    constructor() ERC20("Piggy Token", "PIGGY") { }
}

contract LockedPiggyBankTest is Test {
    PiggyToken public piggy;
    LockedPiggyBank public piggyBank;

    address public owner;
    address public user1;
    address public user2;

    uint256 public constant INITIAL_BALANCE = 1000 * 1e18;
    uint256 public constant LOCK_DURATION = 69 days;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        piggy = new PiggyToken();
        piggyBank = new LockedPiggyBank(IERC20(address(piggy)));

        // Setup initial balances
        deal(address(piggy), user1, INITIAL_BALANCE);
        deal(address(piggy), user2, INITIAL_BALANCE);
    }

    function test_Constructor() public view {
        assertEq(address(piggyBank.asset()), address(piggy));
        assertEq(piggyBank.name(), "PIGGY BANK");
        assertEq(piggyBank.symbol(), "BANK");
    }

    function test_Deposit() public {
        uint256 depositAmount = 100 * 1e18;

        vm.startPrank(user1, user1);
        piggy.approve(address(piggyBank), depositAmount);
        uint256 shares = piggyBank.deposit(depositAmount, user1);
        vm.stopPrank();

        assertEq(shares, depositAmount); // 1:1 ratio
        assertEq(piggyBank.balanceOf(user1), depositAmount);
        assertEq(piggy.balanceOf(address(piggyBank)), depositAmount);
        assertTrue(piggyBank.isLocked(user1));
    }

    function test_Mint() public {
        uint256 mintAmount = 100 * 1e18;

        vm.startPrank(user1, user1);
        piggy.approve(address(piggyBank), mintAmount);
        uint256 assets = piggyBank.mint(mintAmount, user1);
        vm.stopPrank();

        assertEq(assets, mintAmount); // 1:1 ratio
        assertEq(piggyBank.balanceOf(user1), mintAmount);
        assertEq(piggy.balanceOf(address(piggyBank)), mintAmount);
        assertTrue(piggyBank.isLocked(user1));
    }

    function test_RedeemBeforeLockExpiry() public {
        uint256 depositAmount = 100 * 1e18;

        vm.startPrank(user1, user1);
        piggy.approve(address(piggyBank), depositAmount);
        piggyBank.deposit(depositAmount, user1);

        vm.expectRevert(abi.encodeWithSelector(LockedPiggyBank.TokensLocked.selector, block.timestamp + LOCK_DURATION));
        piggyBank.redeem(depositAmount, user1, user1);
        vm.stopPrank();
    }

    function test_WithdrawBeforeLockExpiry() public {
        uint256 depositAmount = 100 * 1e18;

        vm.startPrank(user1, user1);
        piggy.approve(address(piggyBank), depositAmount);
        piggyBank.deposit(depositAmount, user1);

        vm.expectRevert(abi.encodeWithSelector(LockedPiggyBank.TokensLocked.selector, block.timestamp + LOCK_DURATION));
        piggyBank.withdraw(depositAmount, user1, user1);
        vm.stopPrank();
    }

    function test_RedeemAfterLockExpiry() public {
        uint256 depositAmount = 100 * 1e18;

        vm.startPrank(user1, user1);
        piggy.approve(address(piggyBank), depositAmount);
        piggyBank.deposit(depositAmount, user1);

        // Move forward past lock period
        vm.warp(block.timestamp + LOCK_DURATION + 1);

        uint256 assets = piggyBank.redeem(depositAmount, user1, user1);
        vm.stopPrank();

        assertEq(assets, depositAmount);
        assertEq(piggyBank.balanceOf(user1), 0);
        assertEq(piggy.balanceOf(user1), INITIAL_BALANCE);
    }

    function test_MaxDepositAndMint() public view {
        assertEq(piggyBank.maxDeposit(user1), type(uint256).max);
        assertEq(piggyBank.maxMint(user1), type(uint256).max);
    }

    function test_MaxWithdrawAndRedeem() public {
        uint256 depositAmount = 100 * 1e18;

        vm.startPrank(user1, user1);
        piggy.approve(address(piggyBank), depositAmount);
        piggyBank.deposit(depositAmount, user1);

        // During lock period
        assertEq(piggyBank.maxWithdraw(user1), 0);
        assertEq(piggyBank.maxRedeem(user1), 0);

        // After lock period
        vm.warp(block.timestamp + LOCK_DURATION + 1);
        assertEq(piggyBank.maxWithdraw(user1), depositAmount);
        assertEq(piggyBank.maxRedeem(user1), depositAmount);
        vm.stopPrank();
    }

    function test_PreviewFunctions() public {
        uint256 depositAmount = 100 * 1e18;

        vm.startPrank(user1, user1);
        piggy.approve(address(piggyBank), depositAmount);
        piggyBank.deposit(depositAmount, user1);

        // During lock period
        vm.expectRevert(abi.encodeWithSelector(LockedPiggyBank.TokensLocked.selector, block.timestamp + LOCK_DURATION));
        piggyBank.previewWithdraw(depositAmount);

        vm.expectRevert(abi.encodeWithSelector(LockedPiggyBank.TokensLocked.selector, block.timestamp + LOCK_DURATION));
        piggyBank.previewRedeem(depositAmount);

        // After lock period
        vm.warp(block.timestamp + LOCK_DURATION + 1);
        assertEq(piggyBank.previewWithdraw(depositAmount), depositAmount);
        assertEq(piggyBank.previewRedeem(depositAmount), depositAmount);
        vm.stopPrank();
    }

    function test_RemainingLockTime() public {
        uint256 depositAmount = 100 * 1e18;

        vm.startPrank(user1, user1);
        piggy.approve(address(piggyBank), depositAmount);
        piggyBank.deposit(depositAmount, user1);

        assertEq(piggyBank.remainingLockTime(user1), LOCK_DURATION);

        // Move forward half the lock period
        vm.warp(block.timestamp + LOCK_DURATION / 2);
        assertEq(piggyBank.remainingLockTime(user1), LOCK_DURATION / 2);

        // Move forward past lock period
        vm.warp(block.timestamp + LOCK_DURATION / 2 + 1);
        assertEq(piggyBank.remainingLockTime(user1), 0);
        vm.stopPrank();
    }

    function test_ZeroDeposit() public {
        vm.startPrank(user1, user1);
        vm.expectRevert(LockedPiggyBank.ZeroDeposit.selector);
        piggyBank.deposit(0, user1);

        vm.expectRevert(LockedPiggyBank.ZeroDeposit.selector);
        piggyBank.mint(0, user1);
        vm.stopPrank();
    }
}
