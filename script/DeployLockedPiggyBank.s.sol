// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { CREATE3Script } from "./base/CREATE3Script.sol";
import "forge-std/console2.sol";
import { LockedPiggyBank } from "../src/LockedPiggyBank.sol";

contract DeployLockedPiggyBank is CREATE3Script {
    // Add storage variables
    address public constant PIGGY = 0xe3CF8dBcBDC9B220ddeaD0bD6342E245DAFF934d;
    address public constant SLOP_BUCKET = 0x618EdCf3418F4eee829D0641166E4499b433de2f;

    constructor() CREATE3Script("SQUEAAAAAL") { }

    function deploy() public {
        vm.startBroadcast();
        assert(PIGGY != address(0));
        assert(SLOP_BUCKET != address(0));

        address lockedPiggyBank = create3.deploy(
            getCreate3ContractSalt("LockedPiggyBank"),
            abi.encodePacked(
                type(LockedPiggyBank).creationCode,
                abi.encode(
                    PIGGY, // _piggyToken
                    SLOP_BUCKET // _slopBucket
                )
            )
        );

        console2.log("LockedPiggyBank deployed to:", lockedPiggyBank);
        console2.log("block.number:", block.number);

        vm.stopBroadcast();
    }
}
