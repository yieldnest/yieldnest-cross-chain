#!/bin/bash
source .env

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

    echo "This script is designed to help deploy Yieldnest tokens to new chains: "
    echo "Please create an input and add the relative path to the script.  For example:"
    echo
    echo "yarn deploy script/inputs/mainnet-ynETH.json"
    echo
    echo "Options:"
    echo "  -h, --help            Display this help and exit"
    echo "  -a, --account         Set the deployer account name"
    echo "  -s, --sender          Set the deployer address"
    echo "  -b, --broadcast       Broadcast the deployment"
    echo "  -v, --verify          Verify the deployment on Etherscan"
    echo "  -f, --force           Broadcast and verify the deployment"

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

# unset private key as we are reading it from cast wallet
PRIVATE_KEY=""
DEPLOYER_ACCOUNT_NAME=${DEPLOYER_ACCOUNT_NAME:-"yieldnestDeployerKey"}
L1_RPC=""
L1_CHAIN_ID=$(jq -r ".l1ChainId" "$INPUT_PATH")
ERC20_NAME=$(jq -r ".erc20Name" "$INPUT_PATH")
L2_CHAIN_IDS_ARRAY=$(jq -r ".l2ChainIds" "$INPUT_PATH" | jq -r ".[]")

OUTPUT_PATH="deployments/ynETH-$L1_CHAIN_ID.json"

# verify env variables
if [[ -z $ETHERSCAN_API_KEY || -z $DEPLOYER_ADDRESS ]]; then
    echo "invalid .env vars"
    exit 1
fi

###############
## FUNCTIONS ##
###############

function simulate() {
    forge script $1 --sig $2 --rpc-url $3 --account $DEPLOYER_ACCOUNT_NAME --sender $DEPLOYER_ADDRESS
}

function broadcast() {
    forge script $1 --sig $2 --rpc-url $3 --account $DEPLOYER_ACCOUNT_NAME --sender $DEPLOYER_ADDRESS --broadcast --slow
}

function verify() {
    forge script $1 --sig $2 --rpc-url $3 --account $DEPLOYER_ACCOUNT_NAME --sender $DEPLOYER_ADDRESS --verify --etherscan-api-key $3 --slow
}

function broadcastAndVerify() {
    forge script $1 --sig $2 --rpc-url $3 --account $DEPLOYER_ACCOUNT_NAME --sender $DEPLOYER_ADDRESS --broadcast --verify --etherscan-api-key $3 --slow
}

function getRPC() {
    local INPUT_ID=$1

    case $INPUT_ID in
    1)
        echo "mainnet"
        ;;
    8453)
        echo "base"
        ;;
    10)
        echo "optimism"
        ;;
    42161)
        echo "arbitrum"
        ;;
    252)
        echo "fraxtal"
        ;;
    169)
        echo "manta"
        ;;
    167000)
        echo "taiko"
        ;;
    534352)
        echo "scroll"
        ;;
    250)
        echo "fantom"
        ;;
    5000)
        echo "mantle"
        ;;
    81457)
        echo "blast"
        ;;
    59144)
        echo "linea"
        ;;
    17000)
        echo "holesky"
        ;;
    11155111)
        echo "sepolia"
        ;;
    2810)
        echo "morph_testnet"
        ;;
    2522)
        echo "fraxtal_testnet"
        ;;
    *)
        echo "Chain RPC not found for $2"
        exit 1
        ;;
    esac
}

# Function to handle errors
function error_exit() {
    echo "Error: $1" >&2
    usage
    exit 1
}

BROADCAST=false
VERIFY=false

function runScript() {
    local SCRIPT=$1
    local CALLDATA=$2
    local RPC=$3

    if [[ $BROADCAST == true && $VERIFY == true ]]; then
        broadcastAndVerify $SCRIPT $CALLDATA $RPC
        return
    fi

    if [[ $BROADCAST == true ]]; then
        broadcast $SCRIPT $CALLDATA $RPC
        return
    fi

    if [[ $VERIFY == true ]]; then
        verify $SCRIPT $CALLDATA $RPC
        return
    fi

    simulate $SCRIPT $CALLDATA $RPC
    read -p "Simulation complete, would you like to broadcast the deployment? (y/N) " yn
    case $yn in
    [Yy]*)
        broadcast $SCRIPT $CALLDATA $RPC
        ;;
    *)
        echo "Skipping broadcast"
        return
        ;;

    esac

    read -p "Deployment complete, would you like to verify on Etherscan? (y/N) " yn
    case $yn in
    [Yy]*)
        verify $SCRIPT $CALLDATA $RPC
        ;;
    *)
        echo "Skipping verifcation"
        return
        ;;

    esac
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
    --verify | -v)
        VERIFY=true
        shift
        ;;
    --force | -f)
        BROADCAST=true
        VERIFY=true
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

delimiter

echo "Deployer Account Name:" $DEPLOYER_ACCOUNT_NAME
echo "Deployer Address: " $DEPLOYER_ADDRESS
echo "ERC20 Symbol: " $ERC20_NAME
echo "L1 Chain: " $L1_RPC
echo "L2 Chains: " ${L2_RPCS_ARRAY[@]}

delimiter

CALLDATA=$(cast calldata "run(string)" "/$INPUT_PATH")

echo "Deploying L1 Adapter for $L1_RPC"
runScript script/DeployL1OFTAdapter.s.sol:DeployL1OFTAdapter $CALLDATA $L1_RPC

delimiter

for l2 in $L2_CHAIN_IDS_ARRAY; do
    L2_RPC=$(getRPC $l2)
    echo "Deploying L2 Adapter for $L2_RPC"
    runScript script/DeployL2OFTAdapter.s.sol:DeployL2OFTAdapter $CALLDATA $L2_RPC

    delimiter
done

echo "Verifying L1 Adapter for $L1_RPC"
simulate script/VerifyL1OFTAdapter.s.sol:VerifyL1OFTAdapter $CALLDATA $L1_RPC

delimiter

for l2 in $L2_CHAIN_IDS_ARRAY; do
    L2_RPC=$(getRPC $l2)
    echo "Verifying L2 Adapter for $L2_RPC"
    simulate script/VerifyL2OFTAdapter.s.sol:VerifyL2OFTAdapter $CALLDATA $L2_RPC

    delimiter
done


exit 0
