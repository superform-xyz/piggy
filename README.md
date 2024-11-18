# PIGGY Bank 🐷

A decentralized farming protocol for earning PIGGY tokens through LP staking.

## Overview

PIGGY Bank consists of two main smart contracts:

1. **Piggy.sol** - The PIGGY ERC20 token contract with Merkle-based token distribution
2. **MasterChef.sol** - Farming contract for staking LP tokens to earn PIGGY rewards

## Contracts

### Piggy Token

- Total Supply: 69,000,000,000 PIGGY
- Symbol: PIGGY
- Decimals: 18

Key features:
- Merkle-based token distribution system
- One-time claim per eligible address
- Merkle root can be locked to prevent further updates
- Unclaimed tokens can be burned after distribution period

### MasterChef

Staking contract that allows users to:
- Deposit LP tokens to earn PIGGY rewards
- Withdraw LP tokens and claim rewards
- Emergency withdraw without rewards in case of issues

Features:
- Fixed PIGGY rewards per block
- Single staking pool implementation
- Reward calculation based on user's share of total LP tokens staked

## Usage

1. Deploy the Piggy Token Contract.
2. Deploy the MasterChef Contract:
    - Pass the Piggy token address, Uniswap V2 LP token address, reward rate (piggyPerBlock), and start block.
    - Send 10% of the total supply to the MasterChef:
        ```solidity
        piggy.transfer(masterChefAddress, TOTAL_SUPPLY / 10);
        ```
3. Users Stake LP Tokens and get PIGGY rewards.