// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PiggyBBQ} from "../src/PiggyBBQ.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployPiggyBBQ is Script {
    // Base mainnet addresses
    address constant PIGGY_TOKEN = 0xe3CF8dBcBDC9B220ddeaD0bD6342E245DAFF934d;
    address constant UP_TOKEN = 0x5b2193fDc451C1f847bE09CA9d13A4Bf60f8c86B;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("Deploying PiggyBBQ...");
        console.log("Deployer:", deployerAddress);
        console.log("PIGGY Token:", PIGGY_TOKEN);
        console.log("UP Token:", UP_TOKEN);

        vm.startBroadcast(deployerPrivateKey);

        PiggyBBQ piggyBBQ = new PiggyBBQ(
            deployerAddress,                // initialOwner
            IERC20(PIGGY_TOKEN),
            IERC20(UP_TOKEN)
        );

        vm.stopBroadcast();

        console.log("PiggyBBQ deployed at:", address(piggyBBQ));
        console.log("");
        console.log("Next steps:");
        console.log("1. Transfer 2,500,000 UP tokens to:", address(piggyBBQ));
        console.log("2. Verify contract on BaseScan");
        console.log("3. Announce campaign to community");
    }
}
