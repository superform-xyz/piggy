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
slop_bucket_constructor_arg="$(cast abi-encode "constructor(address,address,address,uint256,uint256)" 0xde587D0C7773BD239fF1bE87d32C876dEd4f7879 0x6CAB55b6b7039795e7BC0A0359f0Ab3a85802B51 0x6CAB55b6b7039795e7BC0A0359f0Ab3a85802B51 1000000000000000000 18167605)"
file_names=(
    "src/Piggy.sol"
    "src/SlopBucket.sol"
    # Add more file names here if needed
)
contract_addresses=(
    0x6CAB55b6b7039795e7BC0A0359f0Ab3a85802B51
    0x932F2D86E467B01dbB4511D820a8F48fE9d8a48D
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

        forge verify-contract $contract_address \
            --chain-id $network \
            --num-of-optimizations 10000 \
            --watch --compiler-version v0.8.28+commit.7893614a \
            --constructor-args "$constructor_arg" \
            "$file_name:$contract_name" \
            --etherscan-api-key "$api_key"
    done
done
