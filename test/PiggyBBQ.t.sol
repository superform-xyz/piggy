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
    MockERC20 public supToken;

    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    uint256 public constant PIGGY_AMOUNT = 100_000_000 * 10**18; // 100M PIGGY
    uint256 public constant SUP_POOL = 2_500_000 * 10**18;        // 2.5M sUP

    function setUp() public {
        // Deploy mock tokens
        piggyToken = new MockERC20("PIGGY", "PIGGY");
        supToken = new MockERC20("sUP", "sUP");

        // Deploy PiggyBBQ contract
        piggyBBQ = new PiggyBBQ(owner, IERC20(address(piggyToken)), IERC20(address(supToken)));

        // Mint tokens to users
        piggyToken.mint(user1, PIGGY_AMOUNT);
        piggyToken.mint(user2, PIGGY_AMOUNT);

        // Mint sUP to contract (simulating owner deposit)
        supToken.mint(address(piggyBBQ), SUP_POOL);
    }

    function test_ConvertPiggy_Success() public {
        uint256 expectedSUP = (PIGGY_AMOUNT * 396) / 10_000_000;

        vm.startPrank(user1);
        piggyToken.approve(address(piggyBBQ), PIGGY_AMOUNT);

        // Expect event
        vm.expectEmit(true, false, false, true);
        emit PiggyBBQ.PiggyConverted(user1, PIGGY_AMOUNT, expectedSUP);

        piggyBBQ.convertPiggy();
        vm.stopPrank();

        // Assertions
        assertEq(piggyToken.balanceOf(user1), 0, "User should have 0 PIGGY");
        assertEq(supToken.balanceOf(user1), expectedSUP, "User should have received sUP");
        assertEq(piggyToken.balanceOf(BURN_ADDRESS), PIGGY_AMOUNT, "PIGGY should be burned");
    }

    function test_ConvertPiggy_CorrectRate() public {
        vm.startPrank(user1);
        piggyToken.approve(address(piggyBBQ), PIGGY_AMOUNT);
        piggyBBQ.convertPiggy();
        vm.stopPrank();

        uint256 supReceived = supToken.balanceOf(user1);
        uint256 expectedSUP = 3_960 * 10**18; // 100M * 0.0000396 = 3,960 sUP

        assertEq(supReceived, expectedSUP, "Conversion rate incorrect");
    }

    function test_RevertWhen_ZeroPiggyBalance() public {
        vm.startPrank(user1);
        // Transfer all PIGGY away
        piggyToken.transfer(user2, PIGGY_AMOUNT);

        vm.expectRevert(PiggyBBQ.ZeroPiggyBalance.selector);
        piggyBBQ.convertPiggy();
        vm.stopPrank();
    }

    function test_RevertWhen_InsufficientSUP() public {
        // Deploy new contract with 0 sUP
        PiggyBBQ emptyBBQ = new PiggyBBQ(owner, IERC20(address(piggyToken)), IERC20(address(supToken)));

        vm.startPrank(user1);
        piggyToken.approve(address(emptyBBQ), PIGGY_AMOUNT);

        uint256 expectedSUP = (PIGGY_AMOUNT * 396) / 10_000_000;
        vm.expectRevert(
            abi.encodeWithSelector(
                PiggyBBQ.InsufficientSUPBalance.selector,
                expectedSUP,
                0
            )
        );
        emptyBBQ.convertPiggy();
        vm.stopPrank();
    }

    function test_RevertWhen_DustAmount() public {
        // Amount too small to produce sUP
        uint256 dustAmount = 25_252; // Less than minimum for 1 wei sUP

        vm.startPrank(user1);
        piggyToken.transfer(user2, PIGGY_AMOUNT - dustAmount);
        piggyToken.approve(address(piggyBBQ), dustAmount);

        vm.expectRevert(PiggyBBQ.ZeroSUPOutput.selector);
        piggyBBQ.convertPiggy();
        vm.stopPrank();
    }

    function test_WithdrawSUP_Owner() public {
        uint256 withdrawAmount = 1_000_000 * 10**18;

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit PiggyBBQ.SUPWithdrawn(owner, withdrawAmount);

        piggyBBQ.withdrawSUP(withdrawAmount);

        assertEq(supToken.balanceOf(owner), withdrawAmount, "Owner should receive sUP");
    }

    function test_RevertWhen_NonOwnerWithdraw() public {
        vm.prank(user1);
        vm.expectRevert();
        piggyBBQ.withdrawSUP(1000 * 10**18);
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

    function test_CalculateSUPOutput() public view {
        uint256 output = piggyBBQ.calculateSUPOutput(PIGGY_AMOUNT);
        uint256 expected = (PIGGY_AMOUNT * 396) / 10_000_000;
        assertEq(output, expected, "Calculation function incorrect");
    }

    function test_GetAvailableSUP() public view {
        uint256 available = piggyBBQ.getAvailableSUP();
        assertEq(available, SUP_POOL, "Available sUP incorrect");
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

        uint256 expectedSUPPerUser = (PIGGY_AMOUNT * 396) / 10_000_000;
        assertEq(supToken.balanceOf(user1), expectedSUPPerUser, "User1 sUP incorrect");
        assertEq(supToken.balanceOf(user2), expectedSUPPerUser, "User2 sUP incorrect");
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

        // Ensure contract has enough sUP
        uint256 totalPiggy = piggyToken.balanceOf(user1);
        uint256 requiredSUP = (totalPiggy * 396) / 10_000_000;
        supToken.mint(address(piggyBBQ), requiredSUP);

        vm.startPrank(user1);
        piggyToken.approve(address(piggyBBQ), totalPiggy);
        piggyBBQ.convertPiggy();
        vm.stopPrank();

        assertEq(piggyToken.balanceOf(user1), 0, "User should have 0 PIGGY");
        assertGt(supToken.balanceOf(user1), 0, "User should have received sUP");
    }
}
