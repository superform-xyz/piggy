// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Piggy.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract PiggyTest is Test {
    Piggy public piggy;
    address public owner;
    address public user1;
    address public user2;
    address public slopBucket;

    // Test data for Merkle tree
    bytes32[] public merkleProof1;
    bytes32[] public merkleProof2;
    bytes32 public merkleRoot;
    uint256 public constant CLAIM_AMOUNT = 100 * 10 ** 18;
    uint256 public constant SLOP_BUCKET_ALLOCATION = 6_900_000_000 * 10 ** 18;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        slopBucket = address(0x3);

        // Deploy contract
        piggy = new Piggy();

        // Create Merkle tree data
        bytes32 leaf1 = keccak256(abi.encodePacked(user1, CLAIM_AMOUNT));
        bytes32 leaf2 = keccak256(abi.encodePacked(user2, CLAIM_AMOUNT));
        merkleRoot = keccak256(abi.encodePacked(leaf1, leaf2));

        // Set merkle proofs (simplified for testing)
        merkleProof1 = new bytes32[](1);
        merkleProof1[0] = leaf2;
        merkleProof2 = new bytes32[](1);
        merkleProof2[0] = leaf1;

        // Set merkle root
        piggy.setMerkleRoot(merkleRoot);
    }

    // Test Constructor
    function test_Constructor() public view {
        assertEq(piggy.name(), "PIGGY");
        assertEq(piggy.symbol(), "PIGGY");
        assertEq(piggy.TOTAL_SUPPLY(), 69_000_000_000 * 10 ** 18);
        assertEq(piggy.balanceOf(address(piggy)), piggy.TOTAL_SUPPLY());
    }

    // Test SlopBucket Allocation
    function test_SendToSlopBucket() public {
        uint256 initialContractBalance = piggy.balanceOf(address(piggy));

        // Call sendToSlopBucket
        piggy.sendToSlopBucket(slopBucket);

        // Verify balances after transfer
        assertEq(piggy.balanceOf(slopBucket), SLOP_BUCKET_ALLOCATION);
        assertEq(piggy.balanceOf(address(piggy)), initialContractBalance - SLOP_BUCKET_ALLOCATION);

        // Verify the function can't be called again
        vm.expectRevert(Piggy.TOKENS_ALREADY_SENT_TO_SLOPE_BUCKET.selector);
        piggy.sendToSlopBucket(slopBucket);
    }

    function test_Revert_SendToSlopBucket_InvalidAddress() public {
        vm.expectRevert(Piggy.INVALID_SLOPE_BUCKET_ADDRESS.selector);
        piggy.sendToSlopBucket(address(0));
    }

    // Test Merkle Root Management
    function test_SetMerkleRoot() public {
        bytes32 newRoot = bytes32(uint256(1));
        piggy.setMerkleRoot(newRoot);
        assertEq(piggy.merkleRoot(), newRoot);
    }

    function testFail_SetMerkleRoot_WhenLocked() public {
        piggy.lockMerkleRoot();
        piggy.setMerkleRoot(bytes32(uint256(1)));
    }

    function test_LockMerkleRoot() public {
        piggy.lockMerkleRoot();
        assertTrue(piggy.isMerkleRootLocked());
    }

    // Test Claim Eligibility
    function test_IsEligibleForClaim() public view {
        assertTrue(piggy.isEligibleForClaim(user1, CLAIM_AMOUNT, merkleProof1));
    }

    function test_IsNotEligibleForClaim_WrongAmount() public view {
        assertFalse(piggy.isEligibleForClaim(user1, CLAIM_AMOUNT + 1, merkleProof1));
    }

    function test_IsNotEligibleForClaim_AfterClaiming() public {
        vm.prank(user1);
        piggy.claimTokens(user1, CLAIM_AMOUNT, merkleProof1);
        assertFalse(piggy.isEligibleForClaim(user1, CLAIM_AMOUNT, merkleProof1));
    }

    // Test Token Claims
    function test_ClaimTokens() public {
        vm.prank(user1);
        piggy.claimTokens(user1, CLAIM_AMOUNT, merkleProof1);
        assertEq(piggy.balanceOf(user1), CLAIM_AMOUNT);
        assertTrue(piggy.hasClaimed(user1));
    }

    function testFail_ClaimTokens_DoubleClaim() public {
        vm.startPrank(user1);
        piggy.claimTokens(user1, CLAIM_AMOUNT, merkleProof1);
        piggy.claimTokens(user1, CLAIM_AMOUNT, merkleProof1);
    }

    function testFail_ClaimTokens_InvalidProof() public {
        vm.prank(user1);
        piggy.claimTokens(user1, CLAIM_AMOUNT, merkleProof2);
    }

    function testFail_ClaimTokens_ZeroAddress() public {
        vm.prank(user1);
        piggy.claimTokens(address(0), CLAIM_AMOUNT, merkleProof1);
    }

    function testFail_ClaimTokens_MerkleRootNotSet() public {
        Piggy newPiggy = new Piggy();
        vm.prank(user1);
        newPiggy.claimTokens(user1, CLAIM_AMOUNT, merkleProof1);
    }

    // Test Burn Functionality
    function test_BurnUnclaimedTokens() public {
        piggy.lockMerkleRoot();
        piggy.sendToSlopBucket(slopBucket);
        piggy.burnUnclaimedTokens();
        assertEq(piggy.balanceOf(address(piggy)), 0);
    }

    function testFail_BurnUnclaimedTokens_WhenNotLocked() public {
        piggy.burnUnclaimedTokens();
    }

    // Test Complete Lifecycle with SlopBucket
    function test_CompleteLifecycleWithSlopBucket() public {
        // 1. Initial state checks
        uint256 totalSupply = piggy.TOTAL_SUPPLY();
        assertEq(piggy.balanceOf(address(piggy)), totalSupply);

        // 2. Send to SlopBucket
        piggy.sendToSlopBucket(slopBucket);
        assertEq(piggy.balanceOf(slopBucket), SLOP_BUCKET_ALLOCATION);

        // 3. Multiple users claim
        vm.prank(user1);
        piggy.claimTokens(user1, CLAIM_AMOUNT, merkleProof1);

        vm.prank(user2);
        piggy.claimTokens(user2, CLAIM_AMOUNT, merkleProof2);

        // 4. Verify claims
        assertEq(piggy.balanceOf(user1), CLAIM_AMOUNT);
        assertEq(piggy.balanceOf(user2), CLAIM_AMOUNT);

        // 5. Lock merkle root
        piggy.lockMerkleRoot();
        assertTrue(piggy.isMerkleRootLocked());

        // 6. Burn unclaimed tokens
        uint256 expectedRemaining = CLAIM_AMOUNT + CLAIM_AMOUNT + SLOP_BUCKET_ALLOCATION; // Amount claimed by user1 and
            // user2 + slop bucket allocation
        piggy.burnUnclaimedTokens();

        // 7. Final state checks
        assertEq(piggy.totalSupply(), expectedRemaining);
        assertEq(piggy.balanceOf(user1), CLAIM_AMOUNT);
        assertEq(piggy.balanceOf(user2), CLAIM_AMOUNT);
        assertEq(piggy.balanceOf(slopBucket), SLOP_BUCKET_ALLOCATION);
    }
}
