#!/bin/bash
source .env
source script/bash/network_config.sh
source script/bash/utils.sh

set -e

##########
## HELP ##
##########

function display_help() {
    delimiter

    echo "This script is designed to help configure Yieldnest tokens on all chains: "
    echo "Please add the input and deployment json paths to the script.  For example:"
    echo
    echo "yarn configure script/inputs/mainnet-ynETH.json deployments/ynETH-1-v0.0.1.json"
    echo
    echo "Options:"
    echo "  -h, --help            Display this help and exit"
    echo "  -a, --account         Set the deployer account name"
    echo "  -s, --sender          Set the deployer address"
    echo "  -b, --simulate-only   Simulate the deployment"
    echo "  -b, --broadcast       Deploy & verify contracts on etherscan"

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

# unset private key as we are reading it from cast wallet
PRIVATE_KEY=""
DEPLOYER_ACCOUNT_NAME=${DEPLOYER_ACCOUNT_NAME:-"yieldnestDeployerKey"}
L1_CHAIN_ID=$(jq -r ".l1ChainId" "$INPUT_PATH")
ERC20_NAME=$(jq -r ".erc20Name" "$INPUT_PATH")
ERC20_SYMBOL=$(jq -r ".erc20Symbol" "$INPUT_PATH")
ERC20_DECIMALS=$(jq -r ".erc20Decimals" "$INPUT_PATH")
L2_CHAIN_IDS_ARRAY=$(jq -r ".l2ChainIds" "$INPUT_PATH" | jq -r ".[]")

# verify env variables
if [[ -z $ETHERSCAN_API_KEY || -z $DEPLOYER_ADDRESS ]]; then
    echo "invalid .env vars"
    exit 1
fi
######################
## SCRIPT EXECUTION ##
######################

# gather flags used if you want to override the .env vars
while [[ $# -gt 0 ]]; do
    case $1 in
    --account | -a)
        checkInput $1 $2
        DEPLOYER_ACCOUNT_NAME=$2
        shift 2
        ;;
    --sender | -s)
        checkInput $1 $2
        DEPLOYER_ADDRESS=$2
        shift 2
        ;;
    --help | -h)
        display_help
        exit 0
        ;;
    --broadcast | -b)
        BROADCAST=true
        shift
        ;;
    --simulate-only | -s)
        SIMULATE_ONLY=true
        shift
        ;;
    --skip-l1 | -l)
        SKIP_L1=true
        shift
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

echo "Deployer Account Name: $DEPLOYER_ACCOUNT_NAME"
echo "Deployer Address: $DEPLOYER_ADDRESS"
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

if [[ $SKIP_L1 == false ]]; then
    echo "Configuring L1 OFTAdapter for $L1_RPC ($L1_CHAIN_ID)"
    runScript ConfigureOFT $CALLDATA $L1_RPC $L1_ETHERSCAN_API_KEY
    
    delimiter
else
    echo "Skipping L1 deployment as requested"
    delimiter
fi

for L2_CHAIN_ID in $L2_CHAIN_IDS_ARRAY; do
    L2_RPC=$(getRPC $L2_CHAIN_ID)
    if [[ -z $L2_RPC ]]; then
        echo "No RPC found for $L2_CHAIN_ID"
        exit 1
    fi
    L2_ETHERSCAN_API_KEY=$(getEtherscanAPIKey $L2_CHAIN_ID)
    if [[ -z $L2_ETHERSCAN_API_KEY ]]; then
        echo "No Etherscan API key found for $L2_CHAIN_ID"
        exit 1
    fi
    echo "Configuring L2 OFTAdapter for $L2_RPC ($L2_CHAIN_ID)"
    runScript ConfigureOFT $CALLDATA $L2_RPC $L2_ETHERSCAN_API_KEY

    delimiter
done

exit 0
