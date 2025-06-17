// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// lib/openzeppelin-contracts/contracts/utils/Context.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// lib/openzeppelin-contracts/contracts/access/Ownable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// src/PiggyDAO.sol

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
