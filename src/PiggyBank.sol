// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PiggyBank is ERC4626 {
    constructor(
        IERC20 _piggyToken
    ) ERC4626(_piggyToken) ERC20("PIGGY BANK", "BANK") {}
}