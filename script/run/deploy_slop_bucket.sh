#!/usr/bin/env bash
# Note: How to set defaultKey - https://www.youtube.com/watch?v=VQe7cIpaE54

export BASE_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_RPC_URL/credential)
export BASE_ETHERSCAN_API_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASESCAN_API_KEY/credential)
export BASE_VERIFIER_URL=https://api.tenderly.co/api/v1/account/superform/project/v1/etherscan/verify/network/8453/public
export TENDERLY_ACCESS_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY/credential)

# Run the script

echo Deploy SlopBucket on Base: ...
forge script script/DeploySlopBucket.s.sol:DeploySlopBucket --sig "deploy()" \
    --rpc-url $BASE_RPC_URL \
    --account default \
    --sender 0x48aB8AdF869Ba9902Ad483FB1Ca2eFDAb6eabe92 \
    --broadcast \
    --slow \
    --legacy
    # --etherscan-api-key $TENDERLY_ACCESS_KEY \
    # --verify \
    # --verifier-url $BASE_VERIFIER_URL \


wait
