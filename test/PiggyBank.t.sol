// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PiggyBank.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PiggyToken is ERC20 {
    constructor() ERC20("Piggy Token", "PIGGY") { }
}

contract PiggyBankTest is Test {
    PiggyToken public piggy;
    PiggyBank public piggyBank;
    address public user;
    uint256 public constant INITIAL_BALANCE = 100 ether;

    function setUp() public {
        user = address(1);
        piggy = new PiggyToken();
        piggyBank = new PiggyBank(IERC20(address(piggy)));
        
        // Give user some tokens
        deal(address(piggy), user, INITIAL_BALANCE);
    }

    function test_Constructor() public view {
        assertEq(address(piggyBank.asset()), address(piggy));
        assertEq(piggyBank.name(), "PIGGY BANK");
        assertEq(piggyBank.symbol(), "BANK");
    }

    function test_Deposit() public {
        uint256 depositAmount = 1 ether;
        
        vm.startPrank(user);
        piggy.approve(address(piggyBank), depositAmount);
        uint256 shares = piggyBank.deposit(depositAmount, user);
        vm.stopPrank();

        assertEq(shares, depositAmount); // 1:1 ratio
        assertEq(piggyBank.balanceOf(user), depositAmount);
        assertEq(piggy.balanceOf(address(piggyBank)), depositAmount);
    }

    function test_Withdraw() public {
        uint256 depositAmount = 1 ether;
        
        vm.startPrank(user);
        piggy.approve(address(piggyBank), depositAmount);
        piggyBank.deposit(depositAmount, user);
        
        uint256 withdrawAmount = depositAmount;
        uint256 assets = piggyBank.withdraw(withdrawAmount, user, user);
        vm.stopPrank();

        assertEq(assets, withdrawAmount);
        assertEq(piggyBank.balanceOf(user), 0);
        assertEq(piggy.balanceOf(user), INITIAL_BALANCE);
    }

    function test_ConversionRatio() public view {
        uint256 assets = 1 ether;
        uint256 shares = piggyBank.convertToShares(assets);
        assertEq(shares, assets); // 1:1 ratio

        uint256 backToAssets = piggyBank.convertToAssets(shares);
        assertEq(backToAssets, assets); // 1:1 ratio
    }
}
