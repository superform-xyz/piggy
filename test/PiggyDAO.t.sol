// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {PiggyDAO} from "../src/PiggyDAO.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Simple Mock ERC20 token for testing
contract MockPiggyToken is ERC20 {
    constructor() ERC20("Mock PIGGY", "MPIGGY") {}
    
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract PiggyDAOTest is Test {
    PiggyDAO public piggyDAO;
    MockPiggyToken public piggyToken;
    
    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public recipient = address(4);
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 public constant DEPOSIT_AMOUNT = 10000 * 10**18;
    
    event PiggyContribution(address indexed user, uint256 amount, uint256 totalUserContributions);
    event Transfer(address indexed recipient, uint256 amount);
    
    function setUp() public {
        // Deploy a mock PIGGY token for testing
        vm.startPrank(owner);
        piggyToken = new MockPiggyToken();
        
        // Mint initial tokens to users
        piggyToken.mint(user1, INITIAL_SUPPLY);
        piggyToken.mint(user2, INITIAL_SUPPLY);
        
        // Deploy the PiggyDAO contract with the mock token
        piggyDAO = new PiggyDAO(piggyToken, owner);
        
        vm.stopPrank();
    }
    
    function testContribute() public {
        vm.startPrank(user1);
        
        // Approve the PiggyDAO contract to spend tokens
        piggyToken.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        
        // Expect the PiggyContribution event to be emitted
        vm.expectEmit(true, false, false, true);
        emit PiggyContribution(user1, DEPOSIT_AMOUNT, DEPOSIT_AMOUNT);
        
        // Contribute tokens
        piggyDAO.contribute(DEPOSIT_AMOUNT);
        
        // Verify contribution was recorded correctly
        assertEq(piggyDAO.userContributions(user1), DEPOSIT_AMOUNT);
        assertEq(piggyDAO.totalContributions(), DEPOSIT_AMOUNT);
        assertEq(piggyToken.balanceOf(address(piggyDAO)), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
    }
    
    function testMultipleContributions() public {
        // First contribution by user1
        vm.startPrank(user1);
        piggyToken.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        piggyDAO.contribute(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Second contribution by user2
        vm.startPrank(user2);
        piggyToken.approve(address(piggyDAO), DEPOSIT_AMOUNT * 2);
        piggyDAO.contribute(DEPOSIT_AMOUNT * 2);
        vm.stopPrank();
        
        // Verify all contributions
        assertEq(piggyDAO.userContributions(user1), DEPOSIT_AMOUNT);
        assertEq(piggyDAO.userContributions(user2), DEPOSIT_AMOUNT * 2);
        assertEq(piggyDAO.totalContributions(), DEPOSIT_AMOUNT * 3);
        assertEq(piggyToken.balanceOf(address(piggyDAO)), DEPOSIT_AMOUNT * 3);
    }
    
    function testTransferTokens() public {
        // First contribute funds to DAO
        vm.startPrank(user1);
        piggyToken.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        piggyDAO.contribute(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Owner transfers tokens directly
        vm.startPrank(owner);
        
        // Expect the Transfer event to be emitted
        vm.expectEmit(true, false, false, true);
        emit Transfer(recipient, DEPOSIT_AMOUNT / 2);
        
        piggyDAO.transferTokens(recipient, DEPOSIT_AMOUNT / 2);
        
        // Verify transfer was executed
        assertEq(piggyToken.balanceOf(recipient), DEPOSIT_AMOUNT / 2);
        assertEq(piggyToken.balanceOf(address(piggyDAO)), DEPOSIT_AMOUNT / 2);
        
        vm.stopPrank();
    }
    
    function testInsufficientBalance() public {
        // First contribute funds to DAO
        vm.startPrank(user1);
        piggyToken.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        piggyDAO.contribute(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Owner attempts to transfer more than available
        vm.startPrank(owner);
        
        // Should revert with InsufficientBalance
        vm.expectRevert(abi.encodeWithSelector(PiggyDAO.InsufficientBalance.selector, DEPOSIT_AMOUNT * 2, DEPOSIT_AMOUNT));
        piggyDAO.transferTokens(recipient, DEPOSIT_AMOUNT * 2);
        
        vm.stopPrank();
    }
    
    function testTransferOwnership() public {
        // Initial owner should be our test owner
        assertEq(piggyDAO.owner(), owner);
        
        // Add some tokens to the DAO first
        vm.startPrank(user1);
        piggyToken.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        piggyDAO.contribute(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Transfer ownership to user1
        vm.prank(owner);
        piggyDAO.transferOwnership(user1);
        
        // Check that ownership was transferred
        assertEq(piggyDAO.owner(), user1);
        
        // Original owner should no longer be able to transfer tokens
        vm.expectRevert();
        vm.prank(owner);
        piggyDAO.transferTokens(recipient, 100);
        
        // New owner should be able to transfer tokens
        vm.prank(user1);
        piggyDAO.transferTokens(recipient, 100);
    }
    
    function testZeroContributionReverts() public {
        vm.startPrank(user1);
        piggyToken.approve(address(piggyDAO), DEPOSIT_AMOUNT);
        
        // Should revert when attempting to contribute zero tokens
        vm.expectRevert(PiggyDAO.ZeroContribution.selector);
        piggyDAO.contribute(0);
        
        vm.stopPrank();
    }
}
