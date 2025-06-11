// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PiggyDAO} from "../src/PiggyDAO.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployPiggyDAO is Script {
    // PIGGY token address provided by the user
    address constant PIGGY_TOKEN_ADDRESS = 0xe3CF8dBcBDC9B220ddeaD0bD6342E245DAFF934d;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy PiggyDAO with the PIGGY token address and the deployer as the initial owner
        PiggyDAO piggyDAO = new PiggyDAO(
            IERC20(PIGGY_TOKEN_ADDRESS),
            deployerAddress
        );
        
        vm.stopBroadcast();
        
        console.log("PiggyDAO deployed at:", address(piggyDAO));
        console.log("Initial owner:", deployerAddress);
        console.log("PIGGY token:", PIGGY_TOKEN_ADDRESS);
    }
}
