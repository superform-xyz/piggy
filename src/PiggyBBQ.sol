// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title PiggyBBQ
 * @dev Contract for converting PIGGY tokens to UP tokens at a fixed rate
 * Part of "The Great Piggy BBQ" campaign to sunset the PIGGY token
 */
contract PiggyBBQ is Ownable, ReentrancyGuard {
    // Immutable token addresses
    IERC20 public immutable piggyToken;
    IERC20 public immutable upToken;

    // Burn address for PIGGY tokens
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // Conversion rate: 0.0000396 UP per PIGGY
    // Calculation: upAmount = (piggyAmount * 396) / 10_000_000
    uint256 public constant CONVERSION_NUMERATOR = 396;
    uint256 public constant CONVERSION_DENOMINATOR = 10_000_000;

    // Events
    event PiggyConverted(
        address indexed user,
        uint256 piggyAmount,
        uint256 upAmount
    );
    event UPWithdrawn(address indexed owner, uint256 amount);

    // Errors
    error ZeroPiggyBalance();
    error ZeroUPOutput();
    error InsufficientUPBalance(uint256 required, uint256 available);
    error InvalidTokenAddress();

    /**
     * @dev Constructor sets token addresses and initial owner
     * @param initialOwner Address that will own the contract
     * @param _piggyToken PIGGY token address (0xe3CF8dBcBDC9B220ddeaD0bD6342E245DAFF934d on Base)
     * @param _upToken UP token address (0x5b2193fdc451c1f847be09ca9d13a4bf60f8c86b on Base)
     */
    constructor(
        address initialOwner,
        IERC20 _piggyToken,
        IERC20 _upToken
    ) Ownable(initialOwner) {
        if (address(_piggyToken) == address(0) ||
            address(_upToken) == address(0) ||
            address(_piggyToken) == address(_upToken)) {
            revert InvalidTokenAddress();
        }
        piggyToken = _piggyToken;
        upToken = _upToken;
    }

    /**
     * @dev Converts caller's entire PIGGY balance to UP tokens
     * Conversion rate: 0.0000396 UP per PIGGY (396 / 10_000_000)
     *
     * Requirements:
     * - Caller must have approved this contract to spend PIGGY tokens
     * - Caller must have non-zero PIGGY balance
     * - Calculated UP amount must be > 0 (prevents dust conversions)
     * - Contract must have sufficient UP balance
     *
     * Effects:
     * - Transfers caller's entire PIGGY balance to burn address (0xdead)
     * - Transfers calculated UP amount to caller
     * - Emits PiggyConverted event
     */
    function convertPiggy() external nonReentrant {
        // Check user's PIGGY balance
        uint256 piggyAmount = piggyToken.balanceOf(msg.sender);
        if (piggyAmount == 0) revert ZeroPiggyBalance();

        // Calculate UP amount to receive
        uint256 upAmount = (piggyAmount * CONVERSION_NUMERATOR) / CONVERSION_DENOMINATOR;
        if (upAmount == 0) revert ZeroUPOutput();

        // Check contract has sufficient UP
        uint256 availableUP = upToken.balanceOf(address(this));
        if (upAmount > availableUP) {
            revert InsufficientUPBalance(upAmount, availableUP);
        }

        // Emit event before state changes (CEI pattern)
        emit PiggyConverted(msg.sender, piggyAmount, upAmount);

        // Transfer PIGGY from user to burn address (user must approve first)
        bool success = piggyToken.transferFrom(msg.sender, BURN_ADDRESS, piggyAmount);
        require(success, "PIGGY transfer failed");

        // Transfer UP from contract to user
        success = upToken.transfer(msg.sender, upAmount);
        require(success, "UP transfer failed");
    }

    /**
     * @dev Allows owner to withdraw UP tokens (e.g., unclaimed tokens after BBQ ends)
     * @param amount Amount of UP tokens to withdraw
     */
    function withdrawUP(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");

        uint256 contractBalance = upToken.balanceOf(address(this));
        require(amount <= contractBalance, "Insufficient contract balance");

        bool success = upToken.transfer(owner(), amount);
        require(success, "UP transfer failed");

        emit UPWithdrawn(owner(), amount);
    }

    /**
     * @dev Calculate UP output for a given PIGGY input (view function for frontend)
     * @param piggyAmount Amount of PIGGY tokens
     * @return upAmount Amount of UP tokens that would be received
     */
    function calculateUPOutput(uint256 piggyAmount) external pure returns (uint256) {
        return (piggyAmount * CONVERSION_NUMERATOR) / CONVERSION_DENOMINATOR;
    }

    /**
     * @dev Returns the current UP balance available for conversions
     * @return balance Available UP token balance in contract
     */
    function getAvailableUP() external view returns (uint256) {
        return upToken.balanceOf(address(this));
    }

    /**
     * @dev Returns the total PIGGY burned (sent to 0xdead address)
     * @return balance Total PIGGY token balance at burn address
     */
    function getTotalPiggyBurned() external view returns (uint256) {
        return piggyToken.balanceOf(BURN_ADDRESS);
    }
}
