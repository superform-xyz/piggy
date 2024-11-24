#!/usr/bin/env bash

export BASESCAN_API_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASESCAN_API_KEY/credential)

networks=(
    84532
    # add more networks here if needed
)

api_keys=(
    $BASESCAN_API_KEY
    # add more API keys here if needed
)

## CONTRACTS VERIFICATION
piggy_constructor_arg="$(cast abi-encode "constructor(address)" 0xde587D0C7773BD239fF1bE87d32C876dEd4f7879)"
slop_bucket_constructor_arg="$(cast abi-encode "constructor(address,address,address,uint256,uint256)" 0xde587D0C7773BD239fF1bE87d32C876dEd4f7879 0xaF0D65608ecAf5Fae4D9Bbb49371876bB5304609 0xaF0D65608ecAf5Fae4D9Bbb49371876bB5304609 1000000000000000000 18183263)"

file_names=(
    "src/Piggy.sol"
    "src/SlopBucket.sol"
    # Add more file names here if needed
)
contract_addresses=(
    0xaF0D65608ecAf5Fae4D9Bbb49371876bB5304609
    0x5f9069f02fDD400516c83B25C2bE3f701B45879b
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
            --num-of-optimizations 10000 \
            --watch --compiler-version v0.8.28+commit.7893614a \
            --constructor-args "$constructor_arg" \
            "$file_name:$contract_name" \
            --etherscan-api-key "$api_key"
    done
done
