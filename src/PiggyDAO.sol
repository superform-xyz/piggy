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
    mapping(address => uint256) public userPiggyContributions;
    uint256 public totalPiggyContributions;
    mapping(address => mapping(address => uint256)) public userERC20Contributions;
    mapping(address => uint256) public totalERC20Contributions;
    
    // Track which ERC20 tokens each user has donated
    mapping(address => address[]) private userDonatedTokensList;
    mapping(address => mapping(address => bool)) private hasUserDonatedToken; // For efficient lookups
    
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
        
        userPiggyContributions[msg.sender] += amount;
        totalPiggyContributions += amount;
        
        emit PiggyContribution(msg.sender, amount, userPiggyContributions[msg.sender]);
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
        
        // Track this token if user hasn't donated it before
        if (!hasUserDonatedToken[msg.sender][tokenAddress]) {
            userDonatedTokensList[msg.sender].push(tokenAddress);
            hasUserDonatedToken[msg.sender][tokenAddress] = true;
        }
        
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
     * @dev Returns all ERC20 tokens a user has donated along with their amounts
     * @param user The address of the user to check
     * @return tokens Array of ERC20 token addresses the user has donated
     * @return amounts Array of corresponding amounts donated for each token
     */
    function getAllUserERC20Contributions(address user) external view returns (address[] memory tokens, uint256[] memory amounts) {
        address[] memory donatedTokens = userDonatedTokensList[user];
        uint256[] memory donatedAmounts = new uint256[](donatedTokens.length);
        
        for (uint256 i = 0; i < donatedTokens.length; i++) {
            donatedAmounts[i] = userERC20Contributions[donatedTokens[i]][user];
        }
        
        return (donatedTokens, donatedAmounts);
    }
    
    /**
     * @dev Returns the total user contributions (both PIGGY and all ERC20s)
     * @param user The address of the user to check
     * @return piggyAmount The user's PIGGY contribution
     * @return erc20Tokens Array of ERC20 token addresses the user has donated
     * @return erc20Amounts Array of corresponding amounts donated for each ERC20 token
     */
    function getUserTotalContributions(address user) external view returns (
        uint256 piggyAmount,
        address[] memory erc20Tokens,
        uint256[] memory erc20Amounts
    ) {
        // Get PIGGY amount
        piggyAmount = userPiggyContributions[user];
        
        // Get all ERC20 contributions
        erc20Tokens = userDonatedTokensList[user];
        erc20Amounts = new uint256[](erc20Tokens.length);
        
        for (uint256 i = 0; i < erc20Tokens.length; i++) {
            erc20Amounts[i] = userERC20Contributions[erc20Tokens[i]][user];
        }
        
        return (piggyAmount, erc20Tokens, erc20Amounts);
    }
}
