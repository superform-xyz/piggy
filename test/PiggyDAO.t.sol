// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {PiggyDAO} from "../src/PiggyDAO.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Simple Mock ERC20 token for testing
contract MockPiggyToken is ERC20 {
    constructor() ERC20("Mock PIGGY", "MPIGGY") {}
    
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

// Another Mock ERC20 token for testing generic ERC20 functionality
contract MockERC20Token is ERC20 {
    constructor() ERC20("Mock Token", "MTKN") {}
    
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract PiggyDAOTest is Test {
    PiggyDAO public piggyDAO;
    MockPiggyToken public piggyToken;
    MockERC20Token public genericToken;
    
    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public recipient = address(4);
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 public constant DEPOSIT_AMOUNT = 10000 * 10**18;
    
    event PiggyContribution(address indexed user, uint256 amount, uint256 totalUserContributions);
    event ERC20Contribution(address indexed token, address indexed user, uint256 amount, uint256 totalUserContributions);
    event Transfer(address indexed recipient, uint256 amount);
    event ERC20Transfer(address indexed token, address indexed recipient, uint256 amount);
    
    function setUp() public {
        // Deploy a mock PIGGY token for testing
        vm.startPrank(owner);
        piggyToken = new MockPiggyToken();
        genericToken = new MockERC20Token();
        
        // Mint initial tokens to users
        piggyToken.mint(user1, INITIAL_SUPPLY);
        piggyToken.mint(user2, INITIAL_SUPPLY);
        genericToken.mint(user1, INITIAL_SUPPLY);
        genericToken.mint(user2, INITIAL_SUPPLY);
        
        // Deploy the PiggyDAO contract with the mock token
        piggyDAO = new PiggyDAO(piggyToken, owner);
        
        vm.stopPrank();
    }
    
    function testContributePiggy() public {
        vm.startPrank(user1);
        
        // Approve the PiggyDAO contract to spend tokens
        piggyToken.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        
        // Expect the PiggyContribution event to be emitted
        vm.expectEmit(true, false, false, true);
        emit PiggyContribution(user1, DEPOSIT_AMOUNT, DEPOSIT_AMOUNT);
        
        // Contribute tokens
        piggyDAO.contributePiggy(DEPOSIT_AMOUNT);
        
        // Verify contribution was recorded correctly
        assertEq(piggyDAO.userPiggyContributions(user1), DEPOSIT_AMOUNT);
        assertEq(piggyDAO.totalPiggyContributions(), DEPOSIT_AMOUNT);
        assertEq(piggyToken.balanceOf(address(piggyDAO)), DEPOSIT_AMOUNT);
        assertEq(piggyDAO.getDaoPiggyBalance(), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
    }
    
    function testMultipleContributions() public {
        // First contribution by user1
        vm.startPrank(user1);
        piggyToken.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        piggyDAO.contributePiggy(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Second contribution by user2
        vm.startPrank(user2);
        piggyToken.approve(address(piggyDAO), DEPOSIT_AMOUNT * 2);
        piggyDAO.contributePiggy(DEPOSIT_AMOUNT * 2);
        vm.stopPrank();
        
        // Verify all contributions
        assertEq(piggyDAO.userPiggyContributions(user1), DEPOSIT_AMOUNT);
        assertEq(piggyDAO.userPiggyContributions(user2), DEPOSIT_AMOUNT * 2);
        assertEq(piggyDAO.totalPiggyContributions(), DEPOSIT_AMOUNT * 3);
        assertEq(piggyDAO.getDaoPiggyBalance(), DEPOSIT_AMOUNT * 3);
    }
    
    function testTransferTokens() public {
        // First contribute funds to DAO
        vm.startPrank(user1);
        piggyToken.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        piggyDAO.contributePiggy(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Owner transfers tokens directly
        vm.startPrank(owner);
        
        // Expect the Transfer event to be emitted
        vm.expectEmit(true, false, false, true);
        emit Transfer(recipient, DEPOSIT_AMOUNT / 2);
        
        piggyDAO.transferPiggyTokens(recipient, DEPOSIT_AMOUNT / 2);
        
        // Verify transfer was executed
        assertEq(piggyToken.balanceOf(recipient), DEPOSIT_AMOUNT / 2);
        assertEq(piggyDAO.getDaoPiggyBalance(), DEPOSIT_AMOUNT / 2);
        
        vm.stopPrank();
    }
    
    function testInsufficientBalance() public {
        // First contribute funds to DAO
        vm.startPrank(user1);
        piggyToken.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        piggyDAO.contributePiggy(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Owner attempts to transfer more than available
        vm.startPrank(owner);
        
        // Should revert with InsufficientBalance
        vm.expectRevert(abi.encodeWithSelector(PiggyDAO.InsufficientBalance.selector, DEPOSIT_AMOUNT * 2, DEPOSIT_AMOUNT));
        piggyDAO.transferPiggyTokens(recipient, DEPOSIT_AMOUNT * 2);
        
        vm.stopPrank();
    }
    
    function testTransferOwnership() public {
        // Initial owner should be our test owner
        assertEq(piggyDAO.owner(), owner);
        
        // Add some tokens to the DAO first
        vm.startPrank(user1);
        piggyToken.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        piggyDAO.contributePiggy(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Transfer ownership to user1
        vm.prank(owner);
        piggyDAO.transferOwnership(user1);
        
        // Check that ownership was transferred
        assertEq(piggyDAO.owner(), user1);
        
        // Original owner should no longer be able to transfer tokens
        vm.expectRevert();
        vm.prank(owner);
        piggyDAO.transferPiggyTokens(recipient, 100);
        
        // New owner should be able to transfer tokens
        vm.prank(user1);
        piggyDAO.transferPiggyTokens(recipient, 100);
    }
    
    function testZeroContributionReverts() public {
        vm.startPrank(user1);
        piggyToken.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        
        // Should revert when attempting to contribute zero tokens
        vm.expectRevert(PiggyDAO.ZeroContribution.selector);
        piggyDAO.contributePiggy(0);
        
        vm.stopPrank();
    }
    
    function testContributeERC20() public {
        vm.startPrank(user1);
        
        // Approve the PiggyDAO contract to spend tokens
        genericToken.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        
        // Expect the ERC20Contribution event to be emitted
        vm.expectEmit(true, true, false, true);
        emit ERC20Contribution(address(genericToken), user1, DEPOSIT_AMOUNT, DEPOSIT_AMOUNT);
        
        // Contribute tokens
        piggyDAO.contributeERC20(address(genericToken), DEPOSIT_AMOUNT);
        
        // Verify contribution was recorded correctly
        assertEq(piggyDAO.userERC20Contributions(address(genericToken), user1), DEPOSIT_AMOUNT);
        assertEq(piggyDAO.totalERC20Contributions(address(genericToken)), DEPOSIT_AMOUNT);
        assertEq(genericToken.balanceOf(address(piggyDAO)), DEPOSIT_AMOUNT);
        assertEq(piggyDAO.getDaoERC20Balance(address(genericToken)), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
    }
    
    function testMultipleERC20Contributions() public {
        // First contribution by user1
        vm.startPrank(user1);
        genericToken.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        piggyDAO.contributeERC20(address(genericToken), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Second contribution by user2
        vm.startPrank(user2);
        genericToken.approve(address(piggyDAO), DEPOSIT_AMOUNT * 2);
        piggyDAO.contributeERC20(address(genericToken), DEPOSIT_AMOUNT * 2);
        vm.stopPrank();
        
        // Verify all contributions
        assertEq(piggyDAO.userERC20Contributions(address(genericToken), user1), DEPOSIT_AMOUNT);
        assertEq(piggyDAO.userERC20Contributions(address(genericToken), user2), DEPOSIT_AMOUNT * 2);
        assertEq(piggyDAO.totalERC20Contributions(address(genericToken)), DEPOSIT_AMOUNT * 3);
        assertEq(piggyDAO.getDaoERC20Balance(address(genericToken)), DEPOSIT_AMOUNT * 3);
    }
    
    function testTransferERC20Tokens() public {
        // First contribute funds to DAO
        vm.startPrank(user1);
        genericToken.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        piggyDAO.contributeERC20(address(genericToken), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Owner transfers tokens directly
        vm.startPrank(owner);
        
        // Expect the ERC20Transfer event to be emitted
        vm.expectEmit(true, true, false, true);
        emit ERC20Transfer(address(genericToken), recipient, DEPOSIT_AMOUNT / 2);
        
        piggyDAO.transferERC20Tokens(address(genericToken), recipient, DEPOSIT_AMOUNT / 2);
        
        // Verify transfer was executed
        assertEq(genericToken.balanceOf(recipient), DEPOSIT_AMOUNT / 2);
        assertEq(genericToken.balanceOf(address(piggyDAO)), DEPOSIT_AMOUNT / 2);
        
        vm.stopPrank();
    }
    
    function testInvalidToken() public {
        vm.startPrank(user1);
        
        // Should revert when using zero address
        vm.expectRevert(PiggyDAO.InvalidToken.selector);
        piggyDAO.contributeERC20(address(0), DEPOSIT_AMOUNT);
        
        // Should revert when using piggyToken address
        vm.expectRevert(PiggyDAO.InvalidToken.selector);
        piggyDAO.contributeERC20(address(piggyToken), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
    }
    
    function testGetAllUserERC20Contributions() public {
        // Set up multiple token contributions from the same user
        MockERC20Token secondToken = new MockERC20Token();
        secondToken.mint(user1, INITIAL_SUPPLY);
        
        vm.startPrank(user1);
        
        // Contribute first token
        genericToken.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        piggyDAO.contributeERC20(address(genericToken), DEPOSIT_AMOUNT);
        
        // Contribute second token
        secondToken.approve(address(piggyDAO), DEPOSIT_AMOUNT * 2);
        piggyDAO.contributeERC20(address(secondToken), DEPOSIT_AMOUNT * 2);
        
        // Get all contributions
        (address[] memory tokens, uint256[] memory amounts) = piggyDAO.getAllUserERC20Contributions(user1);
        
        // Verify token list and amounts
        assertEq(tokens.length, 2);
        assertEq(amounts.length, 2);
        
        // Check first token
        assertEq(tokens[0], address(genericToken));
        assertEq(amounts[0], DEPOSIT_AMOUNT);
        
        // Check second token
        assertEq(tokens[1], address(secondToken));
        assertEq(amounts[1], DEPOSIT_AMOUNT * 2);
        
        vm.stopPrank();
    }
    
    function testGetUserTotalContributions() public {
        // Set up both piggy and ERC20 contributions
        MockERC20Token secondToken = new MockERC20Token();
        secondToken.mint(user1, INITIAL_SUPPLY);
        
        vm.startPrank(user1);
        
        // Contribute PIGGY
        piggyToken.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        piggyDAO.contributePiggy(DEPOSIT_AMOUNT);
        
        // Contribute first ERC20 token
        genericToken.approve(address(piggyDAO), DEPOSIT_AMOUNT * 2);
        piggyDAO.contributeERC20(address(genericToken), DEPOSIT_AMOUNT * 2);
        
        // Contribute second ERC20 token
        secondToken.approve(address(piggyDAO), DEPOSIT_AMOUNT * 3);
        piggyDAO.contributeERC20(address(secondToken), DEPOSIT_AMOUNT * 3);
        
        // Get all contributions
        (uint256 piggyAmount, address[] memory tokens, uint256[] memory amounts) = 
            piggyDAO.getUserTotalContributions(user1);
        
        // Verify PIGGY amount
        assertEq(piggyAmount, DEPOSIT_AMOUNT);
        
        // Verify token lists and amounts
        assertEq(tokens.length, 2);
        assertEq(amounts.length, 2);
        
        // Check first token
        assertEq(tokens[0], address(genericToken));
        assertEq(amounts[0], DEPOSIT_AMOUNT * 2);
        
        // Check second token
        assertEq(tokens[1], address(secondToken));
        assertEq(amounts[1], DEPOSIT_AMOUNT * 3);
        
        vm.stopPrank();
    }
    
    function testMultipleERC20TokenTracking() public {
        // Create multiple tokens
        MockERC20Token token1 = new MockERC20Token();
        MockERC20Token token2 = new MockERC20Token();
        MockERC20Token token3 = new MockERC20Token();
        
        token1.mint(user1, INITIAL_SUPPLY);
        token2.mint(user1, INITIAL_SUPPLY);
        token3.mint(user1, INITIAL_SUPPLY);
        
        vm.startPrank(user1);
        
        // Contribute all three tokens
        token1.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        piggyDAO.contributeERC20(address(token1), DEPOSIT_AMOUNT);
        
        token2.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        piggyDAO.contributeERC20(address(token2), DEPOSIT_AMOUNT);
        
        token3.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        piggyDAO.contributeERC20(address(token3), DEPOSIT_AMOUNT);
        
        // Get all contributions
        (address[] memory tokens, uint256[] memory amounts) = piggyDAO.getAllUserERC20Contributions(user1);
        
        // Verify three tokens were tracked
        assertEq(tokens.length, 3);
        assertEq(amounts.length, 3);
        
        // Verify each token in the list
        bool foundToken1 = false;
        bool foundToken2 = false;
        bool foundToken3 = false;
        
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(token1)) {
                foundToken1 = true;
                assertEq(amounts[i], DEPOSIT_AMOUNT);
            } else if (tokens[i] == address(token2)) {
                foundToken2 = true;
                assertEq(amounts[i], DEPOSIT_AMOUNT);
            } else if (tokens[i] == address(token3)) {
                foundToken3 = true;
                assertEq(amounts[i], DEPOSIT_AMOUNT);
            }
        }
        
        assertTrue(foundToken1);
        assertTrue(foundToken2);
        assertTrue(foundToken3);
        
        vm.stopPrank();
    }
    
    function testERC20InsufficientBalance() public {
        // First contribute funds to DAO
        vm.startPrank(user1);
        genericToken.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        piggyDAO.contributeERC20(address(genericToken), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Owner attempts to transfer more than available
        vm.startPrank(owner);
        
        // Should revert with InsufficientBalance
        vm.expectRevert(abi.encodeWithSelector(PiggyDAO.InsufficientBalance.selector, DEPOSIT_AMOUNT * 2, DEPOSIT_AMOUNT));
        piggyDAO.transferERC20Tokens(address(genericToken), recipient, DEPOSIT_AMOUNT * 2);
        
        vm.stopPrank();
    }
}
