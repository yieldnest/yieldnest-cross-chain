#!/bin/bash
source .env

set -e

echo "EXECUTING"
######################
## GLOBAL VARIABLES ##
######################
# // forge script script/DeployL1OFTAdapter.s.sol:DeployL1OFTAdapter \
# // --rpc-url ${rpc} --sig "run(string calldata)" ${path} \
# // --account ${deployerAccountName} --sender ${deployer} \
# // --broadcast --etherscan-api-key ${api} --verify

# unset private key as we are reading it from cast wallet
PRIVATE_KEY=""
DEPLOYER_ACCOUNT_NAME=${DEPLOYER_ACCOUNT_NAME:-"yieldnestDeployerKey"}
L1_RPC_URL=""

# verify env variables
if [[ -z $ETHERSCAN_API_KEY || -z $DEPLOYER_ADDRESS ]]; then
    echo "invalid .env vars"
    exit 1
fi

###############
## FUNCTIONS ##
###############
function delimitier() {
    echo '#################################################'
}

function broadcast() {
    forge script $1 -s $2 --rpc-url $3 --account $DEPLOYER_ACCOUNT_NAME --sender $DEPLOYER_ADDRESS --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify
}

function simulate() {
    forge script $1 -s $2 --rpc-url $3 --account $DEPLOYER_ACCOUNT_NAME --sender $DEPLOYER_ADDRESS
}

function display_help() {
    echo "Displaying help"
}

function getRpcEndpoints() {
    local ids=("$@")
    for i in "${ids[@]}"; do
        echo "$(getEndpoint $i)"
    done
}

function getEndpoint() {
    INPUT_ID=$1
    if [[ $INPUT_ID != "[" || $INPUT_ID != "]" ]]; then
        case $INPUT_ID in
        1)
            echo ${MAINNET_RPC_URL}
            ;;
        8453)
            #base
            echo ${BASE_RPC_URL}
            ;;
        10)
            #optimism
            echo ${OPTIMISM_RPC_URL}
            ;;
        42161)
            #arbitrum
            echo ${ARBITRUM_RPC_URL}
            ;;
        252)
            #fraxal
            echo ${FRAX_RPC_URL}
            ;;
        17000)
            #holskey
            echo ${HOLESKY_RPC_URL}
            ;;
        2522)
            #fraxalTestnet
            echo ${FRAX_TESTNET_RPC_URL}
            ;;
        *)
            echo "Unrecognized Chain id"
            exit 1
            ;;
        esac
    fi
}

# Function to handle errors
function error_exit() {
    echo "Error: $1" >&2
    usage
    exit 1
}

function checkInput() {
    if [[ -z $2 || "$2" == -* ]]; then
        error_exit "Missing value for parameter $1"
    fi
}
FILE_PATH=$1
if [[ "$FILE_PATH" == "" ]]; then
    echo ""
    display_help
    shift
elif [[ -z $FILE_PATH && -f $FILE_PATH ]]; then
    exit 1
elif [[ -f $FILE_PATH ]]; then
    INPUT_JSON=$1
    shift
    while [[ $# -gt 0 ]]; do
        case $1 in
        --l1-rpc-url | -l1)
            checkInput $1 $2
            L1_RPC_URL=${rpc}
            shift 2
            ;;
        --etherscan-api-key | -api)
            checkInput $1 $2
            ETHERSCAN_API_KEY=${api}
            shift 2
            ;;
        --deployer-account-name | -account)
            checkInput $1 $2
            DEPLOYER_ACCOUNT_NAME=${account}
            shift 2
            ;;
        --deployer-account-address | -sender)
            checkInput $1 $2
            DEPLOYER_ADDRESS=${sender}
            shift 2
            ;;
        --help | -h)
            display_help
            ;;
        *)
            echo "Error, unrecognized flag" >&2
            display_help
            ;;
        esac
    done
else
    echo "unrecognized input"
    exit 1
fi

L1_CHAIN_ID=$(jq -r ".l1ChainId" "$INPUT_JSON")
ERC20_NAME=$(jq -r ".erc20Name" "$INPUT_JSON")
L2_CHAIN_IDS_ARRAY=$(jq -r ".l2ChainIds" "$INPUT_JSON" | jq -r ".[]")
L2_ENDPOINTS_ARRAY=$(< <(getRpcEndpoints $L2_CHAIN_IDS_ARRAY))
L1_RPC_URL=$(getEndpoint $L1_CHAIN_ID)

# if [[ -z L1_RPC_URL ]]; then
#     echo "Valid rpc required"
#     exit 1
# fi

echo "Input json: $INPUT_JSON"
echo "chain id: $L1_CHAIN_ID"
echo "erc20 name: $ERC20_NAME"
echo "deployer acount name: $DEPLOYER_ACCOUNT_NAME"
echo "deployer account address: $DEPLOYER_ADDRESS"
echo "l1 rpc url: $L1_RPC_URL"
echo "L2 rpcs:"
echo "$L2_ENDPOINTS_ARRAY"
exit 0
