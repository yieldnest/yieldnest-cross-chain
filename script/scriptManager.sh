#!/bin/bash
source .env

set -e

######################
## GLOBAL VARIABLES ##
######################

FILE_PATH=$1
# if the first character of the path is a / trim it off
if [[ "${FILE_PATH:0:1}" == "/" ]]; then
    FILE_PATH="${FILE_PATH:1}"
fi

# check that there is an arg
if [[ -z $FILE_PATH ]]; then
    # if no file path display help
    display_help
    exit 1
    #if arg is a filepath and is a file shift down 1 arg
elif [[ -f $FILE_PATH ]]; then
    shift
fi

# unset private key as we are reading it from cast wallet
PRIVATE_KEY=""
DEPLOYER_ACCOUNT_NAME=${DEPLOYER_ACCOUNT_NAME:-"yieldnestDeployerKey"}
L1_RPC_URL=""
L1_CHAIN_ID=$(jq -r ".l1ChainId" "$FILE_PATH")
ERC20_NAME=$(jq -r ".erc20Name" "$FILE_PATH")
RATE=$(jq -r ".rateLimitConfig.limit" "$FILE_PATH")
L2_CHAIN_IDS_ARRAY=$(jq -r ".l2ChainIds" "$FILE_PATH" | jq -r ".[]")
OUTPUT_JSON_PATH="deployments/ynETH-$L1_CHAIN_ID.json"

# verify env variables
if [[ -z $ETHERSCAN_API_KEY || -z $DEPLOYER_ADDRESS ]]; then
    echo "invalid .env vars"
    exit 1
fi

###############
## FUNCTIONS ##
###############
function delimitier() {
    echo '###################################################'
}

function broadcast() {
    echo "broadcasting..."
    forge script $1 -s $2 --rpc-url $3 --account $DEPLOYER_ACCOUNT_NAME --sender $DEPLOYER_ADDRESS --broadcast
    # forge script $1 -s $2 --rpc-url $3 --account $DEPLOYER_ACCOUNT_NAME --sender $DEPLOYER_ADDRESS --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify
}

function simulate() {
    echo "simulating..."
    forge script $1 -s $2 --rpc-url $3 --account $DEPLOYER_ACCOUNT_NAME --sender $DEPLOYER_ADDRESS
}

function display_help() {
    clear
    delimitier
    echo
    echo "This script is designed to help deploy Yieldnest tokens to new chains: "
    echo "Please create an input and add the relative path to the script.  For example ..."
    echo
    echo "yarn script-manager script/inputs/mainnet-ynETH.json"
    echo
    delimitier
}

function getRpcEndpoints() {
    local ids=("$@")
    for i in "${ids[@]}"; do
        echo "$(getEndpoint $i)"
    done
}

function searchArray() {
    local match=$1
    local array=$2

    for i in "${!array[@]}"; do
        [[ "${array[i]}" == "${match}" ]] && break
    done
    echo $i
}

function getEndpoint() {
    INPUT_ID=$1
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
        break
        ;;
    esac
}

# Function to handle errors
function error_exit() {
    echo "Error: $1" >&2
    usage
    exit 1
}

function deployL1OFTAdapter() {
    echo "$1 $2"
    # call simulation
    simulate script/DeployL1OFTAdapter.s.sol:DeployL1OFTAdapter $1 $2
    read -p "Simulation Complete would you like to deploy the L1OFTAdapter? (y/n) " yn
    case $yn in
    [Yy]*)
        broadcast script/DeployL1OFTAdapter.s.sol:DeployL1OFTAdapter $1 $2
        ;;
    [Nn]*) ;;

    esac
}

function deployL2OFTAdapter() {
    echo "$1 $2"
    # call simulation
    simulate script/DeployL2OFTAdapter.s.sol:DeployL2OFTAdapter $1 $2
    read -p "Simulation Complete would you like to deploy the L2OFTAdapter? (y/n) " yn
    case $yn in
    [Yy]*)
        broadcast script/DeployL2OFTAdapter.s.sol:DeployL2OFTAdapter $1 $2
        ;;
    [Nn]*) ;;

    esac
}

function findRPC() {
    local CHAIN_ID=$1

    RPC_URL=$(getEndpoint $1)

    if [[ -z $RPC_URL ]]; then
        echo "Chain RPC not found for $2"
        exit 1
    fi

    echo $RPC_URL
}

function checkInput() {
    if [[ -z $2 || $2 == -* ]]; then
        error_exit "Missing value for parameter $1"
    fi
}

function isAddressEmpty() {
  if [[ -z "$1" || "$1" == "null" || "$1" == "0x0000000000000000000000000000000000000000" ]]; then
    return 0  # return 0 indicates success
  else
    return 1  # return 1 indicates failure
  fi
}

######################
## SCRIPT EXECUTION ##
######################

# gather flags used if you want to override the .env vars
while [[ $# -gt 0 ]]; do
    case $1 in
    --l1-rpc-url | -l1)
        checkInput $1 $2
        L1_RPC_URL=$2
        shift 2
        ;;
        # pass in an array of rpc's
    --l2-rpc-urls | -l2)
        checkInput $1 $2
        L2_ENDPOINTS_ARRAY=$2
        shift 2
        ;;
    --etherscan-api-key | -api)
        checkInput $1 $2
        ETHERSCAN_API_KEY=$2
        shift 2
        ;;
    --deployer-account-name | -a)
        checkInput $1 $2
        DEPLOYER_ACCOUNT_NAME=$2
        shift 2
        ;;
    --sender-account-address | -s)
        checkInput $1 $2
        DEPLOYER_ADDRESS=$2
        shift 2
        ;;
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

# if rpc url is not set by flag set it here
if [[ -z "$L1_RPC_URL" ]]; then
    L1_RPC_URL=$(getEndpoint $L1_CHAIN_ID)
fi

# if there is no l2 endpoints set them
if [[ "${#L2_ENDPOINTS_ARRAY[@]}" == 0 ]]; then
    L2_ENDPOINTS_ARRAY=$(< <(getRpcEndpoints $L2_CHAIN_IDS_ARRAY))
fi

# verify the l1 rpc has been set
if [[ -z "$L1_RPC_URL" || "$L1_RPC_URL" == "Unrecognized Chain Id" ]]; then
    echo "Valid rpc required"
    exit 1
fi

# if the number of rpc's is less than the number of L2 chain ids
if [[ "${#L2_CHAIN_IDS_ARRAY[@]}" != "${#L2_ENDPOINTS_ARRAY[@]}" ]]; then
    echo "Invalid L2 RPCs"
    exit 1
fi

echo "Deploying with account name:" $DEPLOYER_ACCOUNT_NAME
echo "DEPLOYER ADDRESS: " $DEPLOYER_ADDRESS
echo "L1 CHAIN ID: " $L1_CHAIN_ID
echo "ERC20 NAME: " $ERC20_NAME
echo "L2 CHAIN IDs: " ${L2_CHAIN_IDS_ARRAY[@]}

CALLDATA=$(cast calldata "run(string)" "/$FILE_PATH")

echo "Deploying L2 Adapters"
for l2 in $L2_CHAIN_IDS_ARRAY; do
    echo "Deploying on chainId: $l2"
    L2_RPC=$(findRPC $l2)
    echo "l2 rpc: " $L2_RPC
    deployL2OFTAdapter $CALLDATA $L2_RPC
done

echo "Deploying L1 Adapters"
echo "Deploying on chainId: $L1_CHAIN_ID"
echo "l1 rpc: " $L1_RPC_URL
deployL1OFTAdapter $CALLDATA $L1_RPC_URL

echo "Script Complete..."
exit 0
