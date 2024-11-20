#!/usr/bin/env bash
# Note: How to set defaultKey - https://www.youtube.com/watch?v=VQe7cIpaE54

export BASE_SEPOLIA_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_SEPOLIA_RPC_URL/credential)
export BASE_SEPOLIA_ETHERSCAN_API_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASESCAN_API_KEY/credential)
export BASE_SEPOLIA_VERIFIER_URL=https://api.tenderly.co/api/v1/account/superform/project/v1/etherscan/verify/network/84532/public
export TENDERLY_ACCESS_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY/credential)

# Run the script

echo Deploy Piggy on BaseSepolia: ...
forge script script/DeployPiggy.s.sol:DeployPiggy --sig "deploy()" \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --account testDeployer \
    --sender 0x76e9b0063546d97a9c2fdbc9682c5fa347b253ba \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --verify \
    --verifier-url $BASE_SEPOLIA_VERIFIER_URL \
    --broadcast \
    --slow

wait
