#!/bin/bash
source .env
source script/bash/network_config.sh

set -e

######################
## GLOBAL VARIABLES ##
######################

INPUT_PATH=$1
# if the first character of the path is a / trim it off
if [[ "${INPUT_PATH:0:1}" == "/" ]]; then
    INPUT_PATH="${INPUT_PATH:1}"
fi

# check that there is an arg
if [[ -z $INPUT_PATH ]]; then
    # if no file path display help
    echo "yarn test:upgrades script/inputs/mainnet-ynETH.json"
    exit 1
    #if arg is a filepath and is a file shift down 1 arg
elif [[ -f $INPUT_PATH ]]; then
    shift
fi

L1_CHAIN_ID=$(jq -r ".l1ChainId" "$INPUT_PATH")
L2_CHAIN_IDS_ARRAY=$(jq -r ".l2ChainIds" "$INPUT_PATH" | jq -r ".[]")

L1_RPC=$(getRPC $L1_CHAIN_ID)

echo "Testing upgrades for $L1_RPC ($L1_CHAIN_ID)"
FOUNDRY_PROFILE=fork forge test test/fork/Upgrades.t.sol -vv --rpc-url $L1_RPC

for L2_CHAIN_ID in $L2_CHAIN_IDS_ARRAY; do
    L2_RPC=$(getRPC $L2_CHAIN_ID)
    if [[ -z $L2_RPC ]]; then
        echo "No RPC found for $L2_CHAIN_ID"
        exit 1
    fi
    echo "Testing upgrades for $L2_RPC ($L2_CHAIN_ID)"
    FOUNDRY_PROFILE=fork forge test test/fork/Upgrades.t.sol -vv --rpc-url $L2_RPC
done
