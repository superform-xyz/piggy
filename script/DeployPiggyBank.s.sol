// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { CREATE3Script } from "./base/CREATE3Script.sol";
import "forge-std/console2.sol";
import { PiggyBank } from "../src/PiggyBank.sol";

contract DeployPiggyBank is CREATE3Script {
    // Add storage variables
    address public constant PIGGY = 0xe3CF8dBcBDC9B220ddeaD0bD6342E245DAFF934d;

    constructor() CREATE3Script("SQUEAAAAAL") { }

    function deploy() public {
        vm.startBroadcast();
        assert(PIGGY != address(0));

        address piggyBank = create3.deploy(
            getCreate3ContractSalt("PiggyBank"),
            abi.encodePacked(
                type(PiggyBank).creationCode,
                abi.encode(
                    PIGGY, // _piggyToken
                )
            )
        );

        console2.log("PiggyBank deployed to:", piggyBank);
        console2.log("block.number:", block.number);

        vm.stopBroadcast();
    }
}