// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PiggyDAO
 * @dev Contract for managing PIGGY token and other ERC20 token deposits and distribution by DAO governance
 */
contract PiggyDAO is Ownable {
    // State Variables
    IERC20 public immutable piggyToken;
    mapping(address => uint256) public userContributions;
    uint256 public totalContributions;
    mapping(address => mapping(address => uint256)) public userERC20Contributions;
    mapping(address => uint256) public totalERC20Contributions;
    
    // Events
    event PiggyContribution(address indexed user, uint256 amount, uint256 totalUserContributions);
    event ERC20Contribution(address indexed token, address indexed user, uint256 amount, uint256 totalUserContributions);
    event Transfer(address indexed recipient, uint256 amount);
    event ERC20Transfer(address indexed token, address indexed recipient, uint256 amount);
    
    // Errors
    error InsufficientBalance(uint256 requested, uint256 available);
    error ZeroContribution();
    error InvalidToken();
    
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
    
    // External functions - write
    
    /**
     * @dev Allows users to contribute PIGGY tokens into the DAO
     * @param amount The amount of PIGGY tokens to contribute
     */
    function contributePiggy(uint256 amount) external {
        if (amount == 0) revert ZeroContribution();
        
        bool success = piggyToken.transferFrom(msg.sender, address(this), amount);
        require(success, "Token transfer failed");
        
        userContributions[msg.sender] += amount;
        totalContributions += amount;
        
        emit PiggyContribution(msg.sender, amount, userContributions[msg.sender]);
    }
    
    /**
     * @dev Allows users to contribute any ERC20 token into the DAO
     * @param tokenAddress The address of the ERC20 token to contribute
     * @param amount The amount of tokens to contribute
     */
    function contributeERC20(address tokenAddress, uint256 amount) external {
        if (amount == 0) revert ZeroContribution();
        if (tokenAddress == address(0)) revert InvalidToken();
        if (tokenAddress == address(piggyToken)) revert InvalidToken();
        
        IERC20 token = IERC20(tokenAddress);
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Token transfer failed");
        
        userERC20Contributions[tokenAddress][msg.sender] += amount;
        totalERC20Contributions[tokenAddress] += amount;
        
        emit ERC20Contribution(tokenAddress, msg.sender, amount, userERC20Contributions[tokenAddress][msg.sender]);
    }
    
    /**
     * @dev Allows the owner to transfer PIGGY tokens directly
     * @param recipient The address to receive the tokens
     * @param amount The amount of tokens to send
     */
    function transferPiggyTokens(address recipient, uint256 amount) external onlyOwner {
        require(recipient != address(0), "Cannot send to zero address");
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 contractBalance = piggyToken.balanceOf(address(this));
        if (amount > contractBalance) {
            revert InsufficientBalance(amount, contractBalance);
        }
        
        bool success = piggyToken.transfer(recipient, amount);
        require(success, "Token transfer failed");
        
        emit Transfer(recipient, amount);
    }
    
    /**
     * @dev Allows the owner to transfer any ERC20 tokens directly
     * @param tokenAddress The address of the ERC20 token to transfer
     * @param recipient The address to receive the tokens
     * @param amount The amount of tokens to send
     */
    function transferERC20Tokens(
        address tokenAddress, 
        address recipient, 
        uint256 amount
    ) external onlyOwner {
        require(tokenAddress != address(0), "Invalid token address");
        require(recipient != address(0), "Cannot send to zero address");
        require(amount > 0, "Amount must be greater than 0");
        
        IERC20 token = IERC20(tokenAddress);
        uint256 contractBalance = token.balanceOf(address(this));
        if (amount > contractBalance) {
            revert InsufficientBalance(amount, contractBalance);
        }
        
        bool success = token.transfer(recipient, amount);
        require(success, "Token transfer failed");
        
        emit ERC20Transfer(tokenAddress, recipient, amount);
    }
    
    // External functions - view
    
    /**
     * @dev Returns the contract's balance of PIGGY tokens
     * @return The balance of PIGGY tokens
     */
    function getDaoPiggyBalance() external view returns (uint256) {
        return piggyToken.balanceOf(address(this));
    }
    
    /**
     * @dev Returns the contract's balance of a specific ERC20 token
     * @param tokenAddress The address of the ERC20 token
     * @return The balance of the specified ERC20 token
     */
    function getDaoERC20Balance(address tokenAddress) external view returns (uint256) {
        require(tokenAddress != address(0), "Invalid token address");
        return IERC20(tokenAddress).balanceOf(address(this));
    }
    
    /**
     * @dev Returns the total PIGGY contributions made by a specific user
     * @param user The address of the user to check
     * @return The total amount of PIGGY tokens contributed by the user
     */
    function getUserPiggyContributions(address user) external view returns (uint256) {
        return userContributions[user];
    }
    
    /**
     * @dev Returns the total PIGGY contributions made by all users
     * @return The total amount of PIGGY tokens contributed
     */
    function getTotalPiggyContributions() external view returns (uint256) {
        return totalContributions;
    }
    
    /**
     * @dev Returns the total contributions of a specific ERC20 token made by a user
     * @param tokenAddress The address of the ERC20 token
     * @param user The address of the user to check
     * @return The total amount of the specified ERC20 token contributed by the user
     */
    function getUserERC20Contributions(
        address tokenAddress, 
        address user
    ) external view returns (uint256) {
        return userERC20Contributions[tokenAddress][user];
    }
    
    /**
     * @dev Returns the total contributions of a specific ERC20 token made by all users
     * @param tokenAddress The address of the ERC20 token
     * @return The total amount of the specified ERC20 token contributed
     */
    function getTotalERC20Contributions(address tokenAddress) external view returns (uint256) {
        return totalERC20Contributions[tokenAddress];
    }
}
