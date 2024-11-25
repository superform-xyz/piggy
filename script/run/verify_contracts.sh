#!/usr/bin/env bash

export BASESCAN_API_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASESCAN_API_KEY/credential)

networks=(
    8453
    # add more networks here if needed
)

api_keys=(
    $BASESCAN_API_KEY
    # add more API keys here if needed
)

## CONTRACTS VERIFICATION
piggy_constructor_arg="$(cast abi-encode "constructor(address)" 0xf82F3D7Df94FC2994315c32322DA6238cA2A2f7f)"
slop_bucket_constructor_arg="$(cast abi-encode "constructor(address,address,address,uint256,uint256)" 0xf82F3D7Df94FC2994315c32322DA6238cA2A2f7f 0xe3CF8dBcBDC9B220ddeaD0bD6342E245DAFF934d 0xF16EAF2801D9dEd435b7fc5F0ec78048C4142C3e 1000000000000000000 22876523)"

file_names=(
    "src/Piggy.sol"
    "src/SlopBucket.sol"
    # Add more file names here if needed
)
contract_addresses=(
    0xe3CF8dBcBDC9B220ddeaD0bD6342E245DAFF934d
    0x618EdCf3418F4eee829D0641166E4499b433de2f
    # Add more addresses here if needed
)

constructor_args=(
    $piggy_constructor_arg
    $slop_bucket_constructor_arg
)

contract_names=(
    "Piggy"
    "SlopBucket"
    # Add more contract names here if needed
)

# loop through networks
for i in "${!networks[@]}"; do
    network="${networks[$i]}"
    api_key="${api_keys[$i]}"

    # loop through file_names and contract_names
    for j in "${!file_names[@]}"; do
        file_name="${file_names[$j]}"
        contract_name="${contract_names[$j]}"
        contract_address="${contract_addresses[$j]}"
        constructor_arg="${constructor_args[$j]}"
        # verify the contract
        echo "Verifying $contract_name at $contract_address on $network"

        forge verify-contract $contract_address \
            --chain-id $network \
            --num-of-optimizations 1000000 \
            --watch --compiler-version v0.8.28+commit.7893614a \
            --constructor-args "$constructor_arg" \
            "$file_name:$contract_name" \
            --etherscan-api-key "$api_key"
    done
done
