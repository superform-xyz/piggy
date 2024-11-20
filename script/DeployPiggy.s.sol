// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { CREATE3Script } from "./base/CREATE3Script.sol";
import "forge-std/console2.sol";
import { Piggy } from "../src/Piggy.sol";
import { SlopBucket } from "../src/SlopBucket.sol";

contract DeployPiggy is CREATE3Script {
    // Add storage variables
    address public constant OWNER = 0xde587D0C7773BD239fF1bE87d32C876dEd4f7879;

    constructor() CREATE3Script("v2") { }

    function deploy() public {
        vm.startBroadcast();

        address piggy = create3.deploy(
            getCreate3ContractSalt("Piggy"), abi.encodePacked(type(Piggy).creationCode, abi.encode(OWNER))
        );
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
                    piggy, // _piggy
                    piggy, // _lpToken (temporary)
                    1e18, // _piggyPerBlock
                    block.number // _startBlock
                )
            )
        );

        // Log deployed addresses
        console2.log("Piggy deployed to:", piggy);
        console2.log("SlopBucket deployed to:", slopBucket);
        console2.log("block.number:", block.number);

        vm.stopBroadcast();
    }
}
