// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { CREATE3Script } from "./base/CREATE3Script.sol";
import "forge-std/console2.sol";
import { SlopBucket } from "../src/SlopBucket.sol";

contract DeployPiggy is CREATE3Script {
    // Add storage variables
    address public constant OWNER = 0xf82F3D7Df94FC2994315c32322DA6238cA2A2f7f;
    address public constant PIGGY = 0xe3CF8dBcBDC9B220ddeaD0bD6342E245DAFF934d;
    address public constant PIGGY_LP = address(0);
    uint256 public constant PIGGY_PER_BLOCK = 0;

    constructor() CREATE3Script("SQUEAAAAAL") { }

    function deploy() public {
        vm.startBroadcast();
        assert(PIGGY != address(0));
        assert(PIGGY_LP != address(0));
        assert(PIGGY_PER_BLOCK > 0);
        // Deploy SlopBucket with parameters:
        // - piggy token address
        // - LP token address (using piggy for now, replace with actual LP token)
        // - piggyPerBlock (example: 1e18 tokens per block)
        // - startBlock (current block number)
        address slopBucket = create3.deploy(
            getCreate3ContractSalt("SlopBucket"),
            abi.encodePacked(
                type(SlopBucket).creationCode,
                abi.encode(
                    OWNER, // _initialOwner
                    PIGGY, // _piggy
                    PIGGY_LP, // _lpToken (temporary)
                    PIGGY_PER_BLOCK, // _piggyPerBlock
                    block.number // _startBlock
                )
            )
        );

        console2.log("SlopBucket deployed to:", slopBucket);
        console2.log("block.number:", block.number);

        vm.stopBroadcast();
    }
}
