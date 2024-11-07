// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract PiggyBank is ERC20, Ownable {
    bytes32 public merkleRoot;
    bool public isMerkleRootLocked;
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;
    mapping(address => bool) public hasClaimed;

    event MerkleRootSet(bytes32 merkleRoot);
    event MerkleRootLocked();
    event TokensClaimed(address indexed user, uint256 amount);

    constructor() Ownable(msg.sender) ERC20("PIGGY", "BANK") {
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
        require(!hasClaimed[user], "Tokens already claimed for this address");
        bytes32 leaf = keccak256(abi.encodePacked(user, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, leaf), "Invalid Merkle proof");
        hasClaimed[user] = true;
        _transfer(address(this), user, amount);
        emit TokensClaimed(user, amount);
    }

    /**
     * @dev Allows the owner to set the Merkle root if it has not been locked.
     * @param _merkleRoot The Merkle root to set.
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        require(!isMerkleRootLocked, "Merkle root is locked and cannot be updated");
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
        require(isMerkleRootLocked, "Cannot burn until Merkle root is locked");
        uint256 remainingBalance = balanceOf(address(this));
        _burn(address(this), remainingBalance);
    }
}
