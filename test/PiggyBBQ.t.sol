// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {PiggyBBQ} from "../src/PiggyBBQ.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PiggyBBQTest is Test {
    PiggyBBQ public piggyBBQ;
    MockERC20 public piggyToken;
    MockERC20 public upToken;

    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    uint256 public constant PIGGY_AMOUNT = 100_000_000 * 10**18; // 100M PIGGY
    uint256 public constant UP_POOL = 2_500_000 * 10**18;        // 2.5M UP

    function setUp() public {
        // Deploy mock tokens
        piggyToken = new MockERC20("PIGGY", "PIGGY");
        upToken = new MockERC20("UP", "UP");

        // Deploy PiggyBBQ contract
        piggyBBQ = new PiggyBBQ(owner, IERC20(address(piggyToken)), IERC20(address(upToken)));

        // Mint tokens to users
        piggyToken.mint(user1, PIGGY_AMOUNT);
        piggyToken.mint(user2, PIGGY_AMOUNT);

        // Mint UP to contract (simulating owner deposit)
        upToken.mint(address(piggyBBQ), UP_POOL);
    }

    function test_ConvertPiggy_Success() public {
        uint256 expectedUP = (PIGGY_AMOUNT * 396) / 10_000_000;

        vm.startPrank(user1);
        piggyToken.approve(address(piggyBBQ), PIGGY_AMOUNT);

        // Expect event
        vm.expectEmit(true, false, false, true);
        emit PiggyBBQ.PiggyConverted(user1, PIGGY_AMOUNT, expectedUP);

        piggyBBQ.convertPiggy();
        vm.stopPrank();

        // Assertions
        assertEq(piggyToken.balanceOf(user1), 0, "User should have 0 PIGGY");
        assertEq(upToken.balanceOf(user1), expectedUP, "User should have received UP");
        assertEq(piggyToken.balanceOf(BURN_ADDRESS), PIGGY_AMOUNT, "PIGGY should be burned");
    }

    function test_ConvertPiggy_CorrectRate() public {
        vm.startPrank(user1);
        piggyToken.approve(address(piggyBBQ), PIGGY_AMOUNT);
        piggyBBQ.convertPiggy();
        vm.stopPrank();

        uint256 upReceived = upToken.balanceOf(user1);
        uint256 expectedUP = 3_960 * 10**18; // 100M * 0.0000396 = 3,960 UP

        assertEq(upReceived, expectedUP, "Conversion rate incorrect");
    }

    function test_RevertWhen_ZeroPiggyBalance() public {
        vm.startPrank(user1);
        // Transfer all PIGGY away
        piggyToken.transfer(user2, PIGGY_AMOUNT);

        vm.expectRevert(PiggyBBQ.ZeroPiggyBalance.selector);
        piggyBBQ.convertPiggy();
        vm.stopPrank();
    }

    function test_RevertWhen_InsufficientUP() public {
        // Deploy new contract with 0 UP
        PiggyBBQ emptyBBQ = new PiggyBBQ(owner, IERC20(address(piggyToken)), IERC20(address(upToken)));

        vm.startPrank(user1);
        piggyToken.approve(address(emptyBBQ), PIGGY_AMOUNT);

        uint256 expectedUP = (PIGGY_AMOUNT * 396) / 10_000_000;
        vm.expectRevert(
            abi.encodeWithSelector(
                PiggyBBQ.InsufficientUPBalance.selector,
                expectedUP,
                0
            )
        );
        emptyBBQ.convertPiggy();
        vm.stopPrank();
    }

    function test_RevertWhen_DustAmount() public {
        // Amount too small to produce UP
        uint256 dustAmount = 25_252; // Less than minimum for 1 wei UP

        vm.startPrank(user1);
        piggyToken.transfer(user2, PIGGY_AMOUNT - dustAmount);
        piggyToken.approve(address(piggyBBQ), dustAmount);

        vm.expectRevert(PiggyBBQ.ZeroUPOutput.selector);
        piggyBBQ.convertPiggy();
        vm.stopPrank();
    }

    function test_WithdrawUP_Owner() public {
        uint256 withdrawAmount = 1_000_000 * 10**18;

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit PiggyBBQ.UPWithdrawn(owner, withdrawAmount);

        piggyBBQ.withdrawUP(withdrawAmount);

        assertEq(upToken.balanceOf(owner), withdrawAmount, "Owner should receive UP");
    }

    function test_RevertWhen_NonOwnerWithdraw() public {
        vm.prank(user1);
        vm.expectRevert();
        piggyBBQ.withdrawUP(1000 * 10**18);
    }

    function test_GetTotalPiggyBurned() public {
        // Initially no PIGGY burned
        uint256 initialBurned = piggyBBQ.getTotalPiggyBurned();

        // User converts PIGGY
        vm.startPrank(user1);
        piggyToken.approve(address(piggyBBQ), PIGGY_AMOUNT);
        piggyBBQ.convertPiggy();
        vm.stopPrank();

        // Check burned amount increased
        uint256 finalBurned = piggyBBQ.getTotalPiggyBurned();
        assertEq(finalBurned - initialBurned, PIGGY_AMOUNT, "Burned amount incorrect");
    }

    function test_RevertWhen_SameTokenAddress() public {
        vm.expectRevert(PiggyBBQ.InvalidTokenAddress.selector);
        new PiggyBBQ(owner, IERC20(address(piggyToken)), IERC20(address(piggyToken)));
    }

    function test_CalculateUPOutput() public view {
        uint256 output = piggyBBQ.calculateUPOutput(PIGGY_AMOUNT);
        uint256 expected = (PIGGY_AMOUNT * 396) / 10_000_000;
        assertEq(output, expected, "Calculation function incorrect");
    }

    function test_GetAvailableUP() public view {
        uint256 available = piggyBBQ.getAvailableUP();
        assertEq(available, UP_POOL, "Available UP incorrect");
    }

    function test_MultipleConversions() public {
        // User1 converts
        vm.startPrank(user1);
        piggyToken.approve(address(piggyBBQ), PIGGY_AMOUNT);
        piggyBBQ.convertPiggy();
        vm.stopPrank();

        // User2 converts
        vm.startPrank(user2);
        piggyToken.approve(address(piggyBBQ), PIGGY_AMOUNT);
        piggyBBQ.convertPiggy();
        vm.stopPrank();

        uint256 expectedUPPerUser = (PIGGY_AMOUNT * 396) / 10_000_000;
        assertEq(upToken.balanceOf(user1), expectedUPPerUser, "User1 UP incorrect");
        assertEq(upToken.balanceOf(user2), expectedUPPerUser, "User2 UP incorrect");
        assertEq(
            piggyToken.balanceOf(BURN_ADDRESS),
            PIGGY_AMOUNT * 2,
            "Burned PIGGY balance incorrect"
        );
    }

    function test_MaximumPiggyAmount() public {
        // Test with maximum outstanding PIGGY supply
        uint256 maxPiggy = 63_123_637_092 * 10**18;
        piggyToken.mint(user1, maxPiggy);

        // Ensure contract has enough UP
        uint256 totalPiggy = piggyToken.balanceOf(user1);
        uint256 requiredUP = (totalPiggy * 396) / 10_000_000;
        upToken.mint(address(piggyBBQ), requiredUP);

        vm.startPrank(user1);
        piggyToken.approve(address(piggyBBQ), totalPiggy);
        piggyBBQ.convertPiggy();
        vm.stopPrank();

        assertEq(piggyToken.balanceOf(user1), 0, "User should have 0 PIGGY");
        assertGt(upToken.balanceOf(user1), 0, "User should have received UP");
    }
}
