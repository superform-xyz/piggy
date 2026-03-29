// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title PiggyBBQ
 * @dev Contract for converting PIGGY tokens to sUP tokens at a fixed rate
 * Part of "The Great Piggy BBQ" campaign to sunset the PIGGY token
 */
contract PiggyBBQ is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Immutable token addresses
    IERC20 public immutable piggyToken;
    IERC20 public immutable supToken;

    // Burn address for PIGGY tokens
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // Conversion rate: 0.0000396 sUP per PIGGY
    // Calculation: supAmount = (piggyAmount * 396) / 10_000_000
    uint256 public constant CONVERSION_NUMERATOR = 396;
    uint256 public constant CONVERSION_DENOMINATOR = 10_000_000;

    // Events
    event PiggyConverted(
        address indexed user,
        uint256 piggyAmount,
        uint256 supAmount
    );
    event SUPWithdrawn(address indexed owner, uint256 amount);

    // Errors
    error ZeroPiggyBalance();
    error ZeroSUPOutput();
    error ZeroAmount();
    error InsufficientSUPBalance(uint256 required, uint256 available);
    error InvalidTokenAddress();

    /**
     * @dev Constructor sets token addresses and initial owner
     * @param initialOwner Address that will own the contract
     * @param _piggyToken PIGGY token address (0xe3CF8dBcBDC9B220ddeaD0bD6342E245DAFF934d on Base)
     * @param _supToken sUP token address (0x2c71f70e2Ec720AE061Ae7E0316fC9654d94f417 on Base)
     */
    constructor(
        address initialOwner,
        IERC20 _piggyToken,
        IERC20 _supToken
    ) Ownable(initialOwner) {
        if (address(_piggyToken) == address(0) ||
            address(_supToken) == address(0) ||
            address(_piggyToken) == address(_supToken)) {
            revert InvalidTokenAddress();
        }
        piggyToken = _piggyToken;
        supToken = _supToken;
    }

    /**
     * @dev Converts caller's entire PIGGY balance to sUP tokens
     * Conversion rate: 0.0000396 sUP per PIGGY (396 / 10_000_000)
     *
     * Requirements:
     * - Caller must have approved this contract to spend PIGGY tokens
     * - Caller must have non-zero PIGGY balance
     * - Calculated sUP amount must be > 0 (prevents dust conversions)
     * - Contract must have sufficient sUP balance
     *
     * Effects:
     * - Transfers caller's entire PIGGY balance to burn address (0xdead)
     * - Transfers calculated sUP amount to caller
     * - Emits PiggyConverted event
     */
    function convertPiggy() external nonReentrant {
        // Check user's PIGGY balance
        uint256 piggyAmount = piggyToken.balanceOf(msg.sender);
        if (piggyAmount == 0) revert ZeroPiggyBalance();

        // Calculate sUP amount to receive
        uint256 supAmount = (piggyAmount * CONVERSION_NUMERATOR) / CONVERSION_DENOMINATOR;
        if (supAmount == 0) revert ZeroSUPOutput();

        // Check contract has sufficient sUP
        uint256 availableSUP = supToken.balanceOf(address(this));
        if (supAmount > availableSUP) {
            revert InsufficientSUPBalance(supAmount, availableSUP);
        }

        // Emit event before external interactions (CEI pattern)
        emit PiggyConverted(msg.sender, piggyAmount, supAmount);

        // Transfer PIGGY from user to burn address (user must approve first)
        piggyToken.safeTransferFrom(msg.sender, BURN_ADDRESS, piggyAmount);

        // Transfer sUP from contract to user
        supToken.safeTransfer(msg.sender, supAmount);
    }

    /**
     * @dev Allows owner to withdraw sUP tokens (e.g., unclaimed tokens after BBQ ends)
     * @param amount Amount of sUP tokens to withdraw
     */
    function withdrawSUP(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 contractBalance = supToken.balanceOf(address(this));
        if (amount > contractBalance) {
            revert InsufficientSUPBalance(amount, contractBalance);
        }

        address currentOwner = owner();
        emit SUPWithdrawn(currentOwner, amount);

        supToken.safeTransfer(currentOwner, amount);
    }

    /**
     * @dev Calculate sUP output for a given PIGGY input (view function for frontend)
     * @param piggyAmount Amount of PIGGY tokens
     * @return supAmount Amount of sUP tokens that would be received
     */
    function calculateSUPOutput(uint256 piggyAmount) external pure returns (uint256) {
        return (piggyAmount * CONVERSION_NUMERATOR) / CONVERSION_DENOMINATOR;
    }

    /**
     * @dev Returns the current sUP balance available for conversions
     * @return balance Available sUP token balance in contract
     */
    function getAvailableSUP() external view returns (uint256) {
        return supToken.balanceOf(address(this));
    }

    /**
     * @dev Returns the total PIGGY burned (sent to 0xdead address)
     * @return balance Total PIGGY token balance at burn address
     */
    function getTotalPiggyBurned() external view returns (uint256) {
        return piggyToken.balanceOf(BURN_ADDRESS);
    }
}
