// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// external
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Piggy is ERC20, Ownable {
    bytes32 public merkleRoot;
    bool public isMerkleRootLocked;
    uint256 public constant TOTAL_SUPPLY = 69_000_000_000 * 10 ** 18;
    bool public hasSentToSlopBucket = false;
    uint256 public constant SLOP_BUCKET_ALLOCATION = 6_900_000_000 * 10 ** 18;
    mapping(address => bool) public hasClaimed;

    event MerkleRootSet(bytes32 merkleRoot);
    event MerkleRootLocked();
    event TokensClaimed(address indexed user, uint256 amount);
    event TokensBurned(uint256 amount);
    event SlopBucketTokensSent(address indexed slopBucket, uint256 amount);

    error MERKLE_ROOT_LOCKED();
    error MERKLE_ROOT_NOT_SET();
    error INVALID_USER_ADDRESS();
    error INVALID_MERKLE_PROOF();
    error TOKENS_ALREADY_CLAIMED();
    error INVALID_SLOPE_BUCKET_ADDRESS();
    error TOKENS_ALREADY_SENT_TO_SLOPE_BUCKET();
    error CANNOT_BURN_UNTIL_MERKLE_ROOT_IS_LOCKED();
    error CANNOT_BURN_UNLESS_SLOPE_BUCKET_HAS_RECEIVED_TOKENS();

    constructor() Ownable(msg.sender) ERC20("PIGGY", "PIGGY") {
        _mint(address(this), TOTAL_SUPPLY);
    }

    /**
     * @dev Check if a user can claim tokens given a Merkle proof.
     * @param user The address of the user to claim tokens for.
     * @param amount The amount of tokens the user is eligible to claim.
     * @param merkleProof The Merkle proof that verifies the user and amount are in the Merkle tree.
     */
    function isEligibleForClaim(
        address user,
        uint256 amount,
        bytes32[] calldata merkleProof
    )
        external
        view
        returns (bool)
    {
        if (hasClaimed[user]) return false;
        bytes32 leaf = keccak256(abi.encodePacked(user, amount));
        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }

    /**
     * @dev Claims tokens for a given user address if the Merkle proof is valid.
     * @param user The address of the user to claim tokens for.
     * @param amount The amount of tokens the user is eligible to claim.
     * @param merkleProof The Merkle proof that verifies the user and amount are in the Merkle tree.
     */
    function claimTokens(address user, uint256 amount, bytes32[] calldata merkleProof) external {
        require(user != address(0), INVALID_USER_ADDRESS());
        require(merkleRoot != bytes32(0), MERKLE_ROOT_NOT_SET());
        require(!hasClaimed[user], TOKENS_ALREADY_CLAIMED());
        bytes32 leaf = keccak256(abi.encodePacked(user, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, leaf), INVALID_MERKLE_PROOF());
        hasClaimed[user] = true;
        _transfer(address(this), user, amount);
        emit TokensClaimed(user, amount);
    }

    /**
     * @dev Allows the owner to set the Merkle root if it has not been locked.
     * @param _merkleRoot The Merkle root to set.
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        require(!isMerkleRootLocked, MERKLE_ROOT_LOCKED());
        merkleRoot = _merkleRoot;
        emit MerkleRootSet(_merkleRoot);
    }

    /**
     * @dev Locks the Merkle root to prevent further updates. This action is irreversible.
     */
    function lockMerkleRoot() external onlyOwner {
        isMerkleRootLocked = true;
        emit MerkleRootLocked();
    }

    /**
     * @dev Burns any unclaimed tokens at the end of the BANK open period.
     * This function can only be called if the Merkle root is locked.
     */
    function burnUnclaimedTokens() external onlyOwner {
        require(isMerkleRootLocked, CANNOT_BURN_UNTIL_MERKLE_ROOT_IS_LOCKED());
        require(hasSentToSlopBucket, CANNOT_BURN_UNLESS_SLOPE_BUCKET_HAS_RECEIVED_TOKENS());
        uint256 remainingBalance = balanceOf(address(this));
        _burn(address(this), remainingBalance);
        emit TokensBurned(remainingBalance);
    }

    /**
     * @dev Sends slop bucket allocation to the SlopBucket.
     * @param slopBucketAddress The address of the SlopBucket contract.
     */
    function sendToSlopBucket(address slopBucketAddress) external onlyOwner {
        require(!hasSentToSlopBucket, TOKENS_ALREADY_SENT_TO_SLOPE_BUCKET());
        require(slopBucketAddress != address(0), INVALID_SLOPE_BUCKET_ADDRESS());
        hasSentToSlopBucket = true;
        _transfer(address(this), slopBucketAddress, SLOP_BUCKET_ALLOCATION);
        emit SlopBucketTokensSent(slopBucketAddress, SLOP_BUCKET_ALLOCATION);
    }
}
