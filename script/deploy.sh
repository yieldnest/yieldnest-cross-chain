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
    echo "  -b, --simulate-only   Simulate the deployment"
    echo "  -b, --broadcast       Deploy & verify contracts on etherscan"
    echo "  -v, --verify-only     Run verify scripts for the deployment"

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
L1_CHAIN_ID=$(jq -r ".l1ChainId" "$INPUT_PATH")
ERC20_NAME=$(jq -r ".erc20Name" "$INPUT_PATH")
ERC20_SYMBOL=$(jq -r ".erc20Symbol" "$INPUT_PATH")
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
    defaultArgs=("--sig" "$2" "--rpc-url" "$3" "--account" "$DEPLOYER_ACCOUNT_NAME" "--sender" "$DEPLOYER_ADDRESS" "--broadcast" "--verify" "--slow" "--password" "")
    
    if [[ $3 == "arbitrum" || $3 == "scroll" ]]; then
        forge script "$1" "${defaultArgs[@]}" --verifier blockscout --verifier-url "https://$3.blockscout.com/api/"
    elif [[ $3 == "bera" ]]; then
        forge script "$1" "${defaultArgs[@]}" --verifier custom --verifier-url "https://api.routescan.io/v2/network/mainnet/evm/80094/etherscan/api"
    elif [[ $3 == "morph_testnet" ]]; then
        forge script "$1" "${defaultArgs[@]}" --verifier blockscout --with-gas-price 0.03gwei --priority-gas-price 0.03gwei --verifier-url "https://explorer-api-holesky.morphl2.io/api?" --chain 2810
    else
        forge script "$1" "${defaultArgs[@]}" --etherscan-api-key "$4"
    fi
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
    80094)
        echo "bera"
        ;;
    *)
        echo ""
        ;;
    esac
}

function getEtherscanAPIKey() {
    local INPUT_ID=$1

    case $INPUT_ID in
    1)
        echo "$ETHERSCAN_API_KEY"
        ;;
    8453)
        echo "$BASESCAN_API_KEY"
        ;;
    10)
        echo "$OPTIMISTIC_ETHERSCAN_API_KEY"
        ;;
    42161)
        echo "$ARBISCAN_API_KEY"
        ;;
    252)
        echo "$FRAXSCAN_API_KEY"
        ;;
    169)
        echo "$MANTASCAN_API_KEY"
        ;;
    167000)
        echo "$TAIKOSCAN_API_KEY"
        ;;
    534352)
        echo "$SCROLLSCAN_API_KEY"
        ;;
    250)
        echo "$FANTOMSCAN_API_KEY"
        ;;
    5000)
        echo "$MANTLESCAN_API_KEY"
        ;;
    81457)
        echo "$BLASTSCAN_API_KEY"
        ;;
    59144)
        echo "$LINEASCAN_API_KEY"
        ;;
    17000)
        echo "$ETHERSCAN_API_KEY"
        ;;
    11155111)
        echo "$ETHERSCAN_API_KEY"
        ;;
    2810)
        echo "$MORPHSCAN_API_KEY"
        ;;
    2522)
        echo "$FRAXSCAN_API_KEY"
        ;;
    80094)
        echo "$BERASCAN_API_KEY"
        ;;
    *)
        echo ""
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
VERIFY_ONLY=false
SIMULATE_ONLY=false

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

    if [[ $SIMULATE_ONLY == true ]]; then
        return 0
    fi

    read -p "Simulation complete, would you like to broadcast the deployment? (y/N) " yn
    case $yn in
    [Yy]*)
        broadcast $SCRIPT $CALLDATA $RPC $ETHERSCAN_API_KEY
        ;;
    *)
        echo "Skipping broadcast"
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
    --verify-only | -v)
        VERIFY_ONLY=true
        shift
        ;;
    --simulate-only | -s)
        SIMULATE_ONLY=true
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

CALLDATA=$(cast calldata "run(string)" "/$INPUT_PATH")

if [[ $VERIFY_ONLY == false ]]; then

    echo "Deploying L1 Adapter for $L1_RPC ($L1_CHAIN_ID)"
    runScript script/DeployL1OFTAdapter.s.sol:DeployL1OFTAdapter $CALLDATA $L1_RPC $L1_ETHERSCAN_API_KEY
    
    delimiter
    
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
        echo "Deploying L2 Adapter for $L2_RPC ($L2_CHAIN_ID)"
        runScript script/DeployL2OFTAdapter.s.sol:DeployL2OFTAdapter $CALLDATA $L2_RPC $L2_ETHERSCAN_API_KEY
    
        delimiter
    done

fi

if [[ $SIMULATE_ONLY == true ]]; then
    exit 0
fi

echo "Verifying L1 Adapter for $L1_RPC ($L1_CHAIN_ID)"
simulate script/VerifyL1OFTAdapter.s.sol:VerifyL1OFTAdapter $CALLDATA $L1_RPC $L1_ETHERSCAN_API_KEY

delimiter

for L2_CHAIN_ID in $L2_CHAIN_IDS_ARRAY; do
    L2_RPC=$(getRPC $L2_CHAIN_ID)
    if [[ -z $L2_RPC ]]; then
        echo "No RPC found for $L2_CHAIN_ID"
        exit 1
    fi
    echo "Verifying L2 Adapter for $L2_RPC ($L2_CHAIN_ID)"
    simulate script/VerifyL2OFTAdapter.s.sol:VerifyL2OFTAdapter $CALLDATA $L2_RPC

    delimiter
done


exit 0
