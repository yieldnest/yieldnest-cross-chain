#!/bin/bash
source .env
source script/bash/network_config.sh

set -e

##########
## HELP ##
##########

function delimiter() {
    echo ""
    echo "###################################################"
    echo ""
}

function display_help() {
    delimiter

    echo "This script is designed to help verify Yieldnest tokens on all chains: "
    echo "Please add the input and deployment json paths to the script.  For example:"
    echo
    echo "yarn verify script/inputs/mainnet-ynETH.json deployments/ynETH-1-v0.0.1.json"
    echo
    echo "Options:"
    echo "  -h, --help            Display this help and exit"

    delimiter
}

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
    display_help
    exit 1
    #if arg is a filepath and is a file shift down 1 arg
elif [[ -f $INPUT_PATH ]]; then
    shift
fi


OUTPUT_PATH=$1
# if the first character of the path is a / trim it off
if [[ "${OUTPUT_PATH:0:1}" == "/" ]]; then
    OUTPUT_PATH="${OUTPUT_PATH:1}"
fi

# check that there is an arg
if [[ -z $OUTPUT_PATH ]]; then
    # if no file path display help
    display_help
    exit 1
    #if arg is a filepath and is a file shift down 1 arg
elif [[ -f $OUTPUT_PATH ]]; then
    shift
fi

L1_CHAIN_ID=$(jq -r ".l1ChainId" "$INPUT_PATH")
ERC20_NAME=$(jq -r ".erc20Name" "$INPUT_PATH")
ERC20_SYMBOL=$(jq -r ".erc20Symbol" "$INPUT_PATH")
L2_CHAIN_IDS_ARRAY=$(jq -r ".l2ChainIds" "$INPUT_PATH" | jq -r ".[]")

###############
## FUNCTIONS ##
###############

function simulate() {
    forge script $1 --sig $2 --rpc-url $3 --account $DEPLOYER_ACCOUNT_NAME --sender $DEPLOYER_ADDRESS
}


# Function to handle errors
function error_exit() {
    echo "Error: $1" >&2
    usage
    exit 1
}

function runScript() {
    local SCRIPT=$1
    local CALLDATA=$2
    local RPC=$3
    local ETHERSCAN_API_KEY=$4

    if [[ $BROADCAST == true ]]; then
        broadcast $SCRIPT $CALLDATA $RPC $ETHERSCAN_API_KEY
        return
    fi

    simulate $SCRIPT $CALLDATA $RPC
}

function checkInput() {
    if [[ -z $2 || $2 == -* ]]; then
        error_exit "Missing value for parameter $1"
    fi
}

function getRPCs() {
    local ids=("$@")
    for i in "${ids[@]}"; do
        echo "$(getRPC $i)"
    done
}

######################
## SCRIPT EXECUTION ##
######################

# gather flags used if you want to override the .env vars
while [[ $# -gt 0 ]]; do
    case $1 in
    --help | -h)
        display_help
        exit 0
        ;;
    *)
        echo "Error, unrecognized flag" >&2
        display_help
        exit 1
        ;;
    esac
done

L1_RPC=$(getRPC $L1_CHAIN_ID)
L2_RPCS_ARRAY=$(< <(getRPCs $L2_CHAIN_IDS_ARRAY))
L1_ETHERSCAN_API_KEY=$(getEtherscanAPIKey $L1_CHAIN_ID)

if [[ -z $L1_RPC ]]; then
    echo "No RPC found for $L1_CHAIN_ID"
    exit 1
fi

if [[ -z $L1_ETHERSCAN_API_KEY ]]; then
    echo "No Etherscan API key found for $L1_CHAIN_ID"
    exit 1
fi

delimiter

echo "ERC20 Name: $ERC20_NAME"
echo "ERC20 Symbol: $ERC20_SYMBOL"
echo "L1 Chain: $L1_RPC ($L1_CHAIN_ID)"

output="L2 Chains: "
for L2_CHAIN_ID in $L2_CHAIN_IDS_ARRAY; do
    L2_RPC=$(getRPC $L2_CHAIN_ID)
    output+="${L2_RPC} (${L2_CHAIN_ID}), "
done

# Remove trailing comma and space
output=${output%, }

echo "$output"

delimiter

CALLDATA=$(cast calldata "run(string,string)" "/$INPUT_PATH" "/$OUTPUT_PATH")

echo "Verifying L1 OFTAdapter for $L1_RPC ($L1_CHAIN_ID)"
simulate VerifyOFT $CALLDATA $L1_RPC $L1_ETHERSCAN_API_KEY

delimiter

for L2_CHAIN_ID in $L2_CHAIN_IDS_ARRAY; do
    L2_RPC=$(getRPC $L2_CHAIN_ID)
    if [[ -z $L2_RPC ]]; then
        echo "No RPC found for $L2_CHAIN_ID"
        exit 1
    fi
    echo "Verifying L2 OFTAdapter for $L2_RPC ($L2_CHAIN_ID)"
    simulate VerifyOFT $CALLDATA $L2_RPC $L1_ETHERSCAN_API_KEY

    delimiter
done

exit 0
