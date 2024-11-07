// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/PiggyBank.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract PiggyBankTest is Test {
    PiggyBank public piggyBank;
    address public owner;
    address public user1;
    address public user2;

    // Test data for Merkle tree
    bytes32[] public merkleProof1;
    bytes32[] public merkleProof2;
    bytes32 public merkleRoot;
    uint256 public constant CLAIM_AMOUNT = 100 * 10 ** 18;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        // Deploy contract
        piggyBank = new PiggyBank();

        // Create Merkle tree data
        // In real scenario, you would generate this off-chain
        bytes32 leaf1 = keccak256(abi.encodePacked(user1, CLAIM_AMOUNT));
        bytes32 leaf2 = keccak256(abi.encodePacked(user2, CLAIM_AMOUNT));
        merkleRoot = keccak256(abi.encodePacked(leaf1, leaf2));

        // Set merkle proofs (simplified for testing)
        merkleProof1 = new bytes32[](1);
        merkleProof1[0] = leaf2;

        merkleProof2 = new bytes32[](1);
        merkleProof2[0] = leaf1;

        // Set merkle root
        piggyBank.setMerkleRoot(merkleRoot);
    }

    // Test Constructor
    function test_Constructor() public {
        assertEq(piggyBank.name(), "PIGGY");
        assertEq(piggyBank.symbol(), "BANK");
        assertEq(piggyBank.TOTAL_SUPPLY(), 1_000_000_000 * 10 ** 18);
        assertEq(piggyBank.balanceOf(address(piggyBank)), piggyBank.TOTAL_SUPPLY());
    }

    // Test Merkle Root Management
    function test_SetMerkleRoot() public {
        bytes32 newRoot = bytes32(uint256(1));
        piggyBank.setMerkleRoot(newRoot);
        assertEq(piggyBank.merkleRoot(), newRoot);
    }

    function testFail_SetMerkleRoot_WhenLocked() public {
        piggyBank.lockMerkleRoot();
        piggyBank.setMerkleRoot(bytes32(uint256(1)));
    }

    function test_LockMerkleRoot() public {
        piggyBank.lockMerkleRoot();
        assertTrue(piggyBank.isMerkleRootLocked());
    }

    // Test Claim Eligibility
    function test_IsEligibleForClaim() public {
        assertTrue(piggyBank.isEligibleForClaim(user1, CLAIM_AMOUNT, merkleProof1));
    }

    function test_IsNotEligibleForClaim_WrongAmount() public {
        assertFalse(piggyBank.isEligibleForClaim(user1, CLAIM_AMOUNT + 1, merkleProof1));
    }

    function test_IsNotEligibleForClaim_AfterClaiming() public {
        vm.prank(user1);
        piggyBank.claimTokens(user1, CLAIM_AMOUNT, merkleProof1);
        assertFalse(piggyBank.isEligibleForClaim(user1, CLAIM_AMOUNT, merkleProof1));
    }

    // Test Token Claims
    function test_ClaimTokens() public {
        vm.prank(user1);
        piggyBank.claimTokens(user1, CLAIM_AMOUNT, merkleProof1);
        assertEq(piggyBank.balanceOf(user1), CLAIM_AMOUNT);
        assertTrue(piggyBank.hasClaimed(user1));
    }

    function testFail_ClaimTokens_DoubleClaim() public {
        vm.startPrank(user1);
        piggyBank.claimTokens(user1, CLAIM_AMOUNT, merkleProof1);
        piggyBank.claimTokens(user1, CLAIM_AMOUNT, merkleProof1);
    }

    function testFail_ClaimTokens_InvalidProof() public {
        vm.prank(user1);
        piggyBank.claimTokens(user1, CLAIM_AMOUNT, merkleProof2);
    }

    function testFail_ClaimTokens_ZeroAddress() public {
        vm.prank(user1);
        piggyBank.claimTokens(address(0), CLAIM_AMOUNT, merkleProof1);
    }

    function testFail_ClaimTokens_MerkleRootNotSet() public {
        // Deploy a new contract instance without setting merkle root
        PiggyBank newPiggyBank = new PiggyBank();

        vm.prank(user1);
        newPiggyBank.claimTokens(user1, CLAIM_AMOUNT, merkleProof1);
    }

    // Test Burn Functionality
    function test_BurnUnclaimedTokens() public {
        piggyBank.lockMerkleRoot();
        uint256 initialSupply = piggyBank.totalSupply();
        piggyBank.burnUnclaimedTokens();
        assertEq(piggyBank.totalSupply(), 0);
    }

    function testFail_BurnUnclaimedTokens_WhenNotLocked() public {
        piggyBank.burnUnclaimedTokens();
    }

    // Test Race Condition Scenario
    function test_ClaimAndBurnRaceCondition() public {
        // Simulate a scenario where claiming and burning happen in close succession
        piggyBank.lockMerkleRoot();

        // User1 claims tokens
        vm.prank(user1);
        piggyBank.claimTokens(user1, CLAIM_AMOUNT, merkleProof1);

        // Owner burns unclaimed tokens
        piggyBank.burnUnclaimedTokens();

        // Verify user1 still has their tokens
        assertEq(piggyBank.balanceOf(user1), CLAIM_AMOUNT);
    }

    // Fuzz Tests
    function testFuzz_ClaimTokens_DifferentAmounts(uint256 amount) public {
        // Bound amount to reasonable values and avoid overflow
        amount = bound(amount, 1, piggyBank.TOTAL_SUPPLY());

        // Create new merkle tree with fuzzed amount
        bytes32 leaf1 = keccak256(abi.encodePacked(user1, amount));
        bytes32 leaf2 = keccak256(abi.encodePacked(user2, amount));

        // Sort leaves to ensure consistent merkle tree
        bytes32[2] memory leaves = [leaf1, leaf2];
        if (uint256(leaf1) > uint256(leaf2)) {
            (leaves[0], leaves[1]) = (leaf2, leaf1);
        }

        bytes32 newRoot = keccak256(abi.encodePacked(leaves[0], leaves[1]));

        // Set proof based on sorted leaves
        bytes32[] memory newProof1 = new bytes32[](1);
        newProof1[0] = (leaves[0] == leaf1) ? leaves[1] : leaves[0];

        piggyBank.setMerkleRoot(newRoot);

        vm.prank(user1);
        piggyBank.claimTokens(user1, amount, newProof1);
        assertEq(piggyBank.balanceOf(user1), amount);
    }

    // Integration Tests
    function test_CompleteLifecycle() public {
        // 1. Initial state checks
        assertEq(piggyBank.balanceOf(address(piggyBank)), piggyBank.TOTAL_SUPPLY());
        assertFalse(piggyBank.isMerkleRootLocked());

        // 2. Multiple users claim
        vm.prank(user1);
        piggyBank.claimTokens(user1, CLAIM_AMOUNT, merkleProof1);

        vm.prank(user2);
        piggyBank.claimTokens(user2, CLAIM_AMOUNT, merkleProof2);

        // 3. Verify claims
        assertEq(piggyBank.balanceOf(user1), CLAIM_AMOUNT);
        assertEq(piggyBank.balanceOf(user2), CLAIM_AMOUNT);

        // 4. Lock merkle root
        piggyBank.lockMerkleRoot();
        assertTrue(piggyBank.isMerkleRootLocked());

        // 5. Burn unclaimed tokens
        uint256 expectedRemaining = CLAIM_AMOUNT * 2; // Amount claimed by user1 and user2
        piggyBank.burnUnclaimedTokens();

        // 6. Final state checks
        assertEq(piggyBank.totalSupply(), expectedRemaining);
        assertEq(piggyBank.balanceOf(user1), CLAIM_AMOUNT);
        assertEq(piggyBank.balanceOf(user2), CLAIM_AMOUNT);
        assertEq(piggyBank.balanceOf(address(piggyBank)), 0);
    }
}
