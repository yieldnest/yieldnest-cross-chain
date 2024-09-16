#!/bin/bash
source .env

set -e


##########
## HELP ##
##########

function delimiter() {
    echo '###################################################'
}

function display_help() {
    delimiter
    echo
    echo "This script is designed to help deploy Yieldnest tokens to new chains: "
    echo "Please create an input and add the relative path to the script.  For example:"
    echo
    echo "yarn deploy script/inputs/mainnet-ynETH.json"
    echo
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

function broadcast() {
    CHAIN=$(cast chain-id --rpc-url $3) forge script $1 --sig $2 --rpc-url $3 --account $DEPLOYER_ACCOUNT_NAME --sender $DEPLOYER_ADDRESS --broadcast
    # TODO: add --verify
}

function simulate() {
    CHAIN=$(cast chain-id --rpc-url $3) forge script $1 --sig $2 --rpc-url $3 --account $DEPLOYER_ACCOUNT_NAME --sender $DEPLOYER_ADDRESS
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
    17000)
        echo "holesky"
        ;;
    11155111)
        echo "sepolia"
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

function deployL1OFTAdapter() {
    if [[ $BROADCAST == true ]]; then
        broadcast script/DeployL1OFTAdapter.s.sol:DeployL1OFTAdapter $1 $2
        echo "Deployed L1OFTAdapter for $2"
        return
    fi

    # call simulation
    simulate script/DeployL1OFTAdapter.s.sol:DeployL1OFTAdapter $1 $2
    read -p "Simulation complete would you like to deploy the L1OFTAdapter? (y/N) " yn
    case $yn in
    [Yy]*)
        broadcast script/DeployL1OFTAdapter.s.sol:DeployL1OFTAdapter $1 $2
        echo "Deployed L1OFTAdapter for $2"
        ;;
    *) 
        echo "Skipping broadcast for L1OFTAdapter"
        ;;

    esac
}

function deployL2OFTAdapter() {
    if [[ $BROADCAST == true ]]; then
        broadcast script/DeployL2OFTAdapter.s.sol:DeployL2OFTAdapter $1 $2
        echo "Deployed L2OFTAdapter for $2"
        return
    fi

    # call simulation
    simulate script/DeployL2OFTAdapter.s.sol:DeployL2OFTAdapter $1 $2
    read -p "Simulation Complete would you like to deploy the L2OFTAdapter? (y/N) " yn
    case $yn in
    [Yy]*)
        broadcast script/DeployL2OFTAdapter.s.sol:DeployL2OFTAdapter $1 $2
        echo "Deployed L2OFTAdapter for $2"
        ;;
    *) 
        echo "Skipping broadcast for L2OFTAdapter"
        ;;

    esac
}

function checkInput() {
    if [[ -z $2 || $2 == -* ]]; then
        error_exit "Missing value for parameter $1"
    fi
}

function getRpcs() {
    local ids=("$@")
    for i in "${ids[@]}"; do
        echo "$(getEndpoint $i)"
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
    *)
        echo "Error, unrecognized flag" >&2
        display_help
        exit 1
        ;;
    esac
done

L1_RPC=$(getRPC $L1_CHAIN_ID)
L2_RPCS_ARRAY=$(< <(getRpcs $L2_CHAIN_IDS_ARRAY))

delimiter
echo ""
echo "Deployer Account Name:" $DEPLOYER_ACCOUNT_NAME
echo "Deployer Address: " $DEPLOYER_ADDRESS
echo "ERC20 Symbol: " $ERC20_NAME
echo "L1 Chain: " $L1_RPC
echo "L2 Chains: " ${L2_RPCS_ARRAY[@]}
echo ""
delimiter

CALLDATA=$(cast calldata "run(string)" "/$INPUT_PATH")

echo ""
for l2 in $L2_CHAIN_IDS_ARRAY; do
    L2_RPC=$(getRPC $l2)
    echo "Deploying L2 Adapter for $L2_RPC"
    deployL2OFTAdapter $CALLDATA $L2_RPC
done

echo ""
delimiter
echo ""

echo "Deploying L1 Adapter for $L1_RPC"
deployL1OFTAdapter $CALLDATA $L1_RPC

echo ""
delimiter
echo ""

echo "Verifying L1 Adapter for $L1_RPC"
simulate script/VerifyL1OFTAdapter.s.sol:VerifyL1OFTAdapter $CALLDATA $L1_RPC

echo ""
delimiter
echo ""

for l2 in $L2_CHAIN_IDS_ARRAY; do
    L2_RPC=$(getRPC $l2)
    echo "Verifying L2 Adapter for $L2_RPC"
    simulate script/VerifyL2OFTAdapter.s.sol:VerifyL2OFTAdapter $CALLDATA $L2_RPC
done

echo ""
delimiter

exit 0
