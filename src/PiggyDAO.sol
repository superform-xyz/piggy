// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PiggyDAO
 * @dev Contract for managing PIGGY token deposits and distribution by DAO governance
 */
contract PiggyDAO is Ownable {
    // The PIGGY token contract
    IERC20 public immutable piggyToken;
    
    // Mapping to track user contributions
    mapping(address => uint256) public userContributions;
    
    // Total contributions received
    uint256 public totalContributions;
    
    // Events
    event PiggyContribution(address indexed user, uint256 amount, uint256 totalUserContributions);
    event Transfer(address indexed recipient, uint256 amount);
    
    // Errors
    error InsufficientBalance(uint256 requested, uint256 available);
    error ZeroContribution();
    
    /**
     * @dev Constructor sets the PIGGY token address and initializes owner
     * @param _piggyToken The address of the PIGGY token
     * @param initialOwner The address of the initial owner
     */
    constructor(
        IERC20 _piggyToken,
        address initialOwner
    ) Ownable(initialOwner) {
        piggyToken = _piggyToken;
    }
    
    /**
     * @dev Allows users to contribute PIGGY tokens into the DAO
     * @param amount The amount of PIGGY tokens to contribute
     */
    function contribute(uint256 amount) external {
        if (amount == 0) revert ZeroContribution();
        
        // Transfer tokens from user to contract
        bool success = piggyToken.transferFrom(msg.sender, address(this), amount);
        require(success, "Token transfer failed");
        
        // Update user contributions
        userContributions[msg.sender] += amount;
        totalContributions += amount;
        
        emit PiggyContribution(msg.sender, amount, userContributions[msg.sender]);
    }
    
    /**
     * @dev Allows the owner to transfer PIGGY tokens directly
     * @param recipient The address to receive the tokens
     * @param amount The amount of tokens to send
     */
    function transferTokens(address recipient, uint256 amount) external onlyOwner {
        require(recipient != address(0), "Cannot send to zero address");
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 contractBalance = piggyToken.balanceOf(address(this));
        if (amount > contractBalance) {
            revert InsufficientBalance(amount, contractBalance);
        }
        
        // Execute the transfer
        bool success = piggyToken.transfer(recipient, amount);
        require(success, "Token transfer failed");
        
        emit Transfer(recipient, amount);
    }
    
    /**
     * @dev Returns the contract's balance of PIGGY tokens
     * @return The balance of PIGGY tokens
     */
    function getDaoBalance() external view returns (uint256) {
        return piggyToken.balanceOf(address(this));
    }
    
    /**
     * @dev Returns the total contributions made by a specific user
     * @param user The address of the user to check
     * @return The total amount of PIGGY tokens contributed by the user
     */
    function getUserContributions(address user) external view returns (uint256) {
        return userContributions[user];
    }
    
    /**
     * @dev Returns the total contributions made by all users
     * @return The total amount of PIGGY tokens contributed
     */
    function getTotalContributions() external view returns (uint256) {
        return totalContributions;
    }
}
