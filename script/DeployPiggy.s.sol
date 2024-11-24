// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { CREATE3Script } from "./base/CREATE3Script.sol";
import "forge-std/console2.sol";
import { Piggy } from "../src/Piggy.sol";

contract DeployPiggy is CREATE3Script {
    // Add storage variables
    address public constant OWNER = 0xde587D0C7773BD239fF1bE87d32C876dEd4f7879;

    constructor() CREATE3Script("SQUEAAAAAL") { }

    function deploy() public {
        vm.startBroadcast();

        address piggy = create3.deploy(
            getCreate3ContractSalt("Piggy"), abi.encodePacked(type(Piggy).creationCode, abi.encode(OWNER))
        );

        // Log deployed addresses
        console2.log("Piggy deployed to:", piggy);

        vm.stopBroadcast();
    }
}
