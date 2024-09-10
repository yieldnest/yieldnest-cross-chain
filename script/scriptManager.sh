#!/bin/bash
source .env

set -e

echo "EXECUTING"
######################
## GLOBAL VARIABLES ##
######################

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
    echo '###################################################'
}

function broadcast() {
    clear
    echo "broadcasting..."
    forge script $1 -s $2 --rpc-url $3 --account $DEPLOYER_ACCOUNT_NAME --sender $DEPLOYER_ADDRESS --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify
}

function simulate() {
    clear
    echo "simulating..."
    forge script $1 -s $2 --rpc-url $3 --account $DEPLOYER_ACCOUNT_NAME --sender $DEPLOYER_ADDRESS
}

function display_help() {
    echo "Help: /n"

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

function selectLayer2RPC() {
    local L2_RPC_URL=''
    local CHAIN_ID_ARRAY=$1
    if [[ "${#CHAIN_ID_ARRAY[@]}" == 1 ]]; then
        L2_RPC_URL="${L2_ENDPOINTS_ARRAY[0]}"
    else
        echo "Please enter the Chain Id you would like to deploy on."
        echo "Chain ids: ${CHAIN_ID_ARRAY[@]}"
        # read -p "enter chain id: " $SELECTED_CHAIN
        arrayIndex=$(searchArray $SELECTED_CHAIN $CHAIN_ID_ARRAY)
        L2_RPC_URL="${L2_ENDPOINTS_ARRAY[${arrayIndex}]}"
        if [[ -z $L2_RPC_URL ]]; then
            echo "Chain RPC not ound for $SELECTED_CHAIN"
            exit 1
        fi
    fi
    echo $L2_RPC_URL
}

function checkInput() {
    if [[ -z $2 || $2 == -* ]]; then
        error_exit "Missing value for parameter $1"
    fi
}

FILE_PATH=$1
# if the first character of the path is a / trim it off
if [[ "${FILE_PATH:0:1}" == "/" ]]; then
    echo "trimming: $FILE_PATH"
    FILE_PATH="${FILE_PATH:1}"
fi
echo "$FILE_PATH"
# check that there is an arg
if [[ -z $FILE_PATH ]]; then
    display_help
    #if arg is a filepath and is a file set input json and shift down 1 arg
elif [[ -f $FILE_PATH ]]; then
    INPUT_JSON=$FILE_PATH
    shift
fi

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

L1_CHAIN_ID=$(jq -r ".l1ChainId" "$INPUT_JSON")
ERC20_NAME=$(jq -r ".erc20Name" "$INPUT_JSON")
L2_CHAIN_IDS_ARRAY=$(jq -r ".l2ChainIds" "$INPUT_JSON" | jq -r ".[]")
L2_ENDPOINTS_ARRAY=$(< <(getRpcEndpoints $L2_CHAIN_IDS_ARRAY))
echo "$L2_ENDPOINTS_ARRAY"
# if rpc url is not set by flag set it here
if [[ -z $L1_RPC_URL ]]; then
    L1_RPC_URL=$(getEndpoint $L1_CHAIN_ID)
fi

# verify the l1 rpc has been set
if [[ -z $L1_RPC_URL || $L1_RPC_URL == "Unrecognized Chain Id" ]]; then
    echo "Valid rpc required"
    exit 1
fi

# if the number of rpc's is less than the number of L2 chain ids
if [[ "${#L2_CHAIN_IDS_ARRAY[@]}" != "${#L2_ENDPOINTS_ARRAY[@]}" ]]; then
    echo "Invalid L2 RPCs"
    exit 1
fi

# forge script script/DeployL1OFTAdapter.s.sol:DeployL1OFTAdapter \
# --rpc-url ${rpc} --sig "run(string calldata)" ${path} \
# --account ${deployerAccountName} --sender ${deployer} \
# --broadcast --etherscan-api-key ${api} --verify

CALLDATA=$(cast calldata "run(string)" "/$FILE_PATH")
clear
echo "What would you like to deploy?"
select deployOptions in new-MultiChainDeployer new-L1-adapter new-L2-adapter set-peers display-help exit; do
    case $deployOptions in
    new-MultiChainDeployer)
        L2_RPC=$(selectLayer2RPC $L2_CHAIN_IDS_ARRAY)
        # call simulation
        simulate script/DeployMultiChainDeployer.s.sol:DeployMultiChainDeployer $CALLDATA $L2_RPC
        echo
        read -p "Simulation complete.  Would You like to broadcast the deployment? (y/n)" yn
        case $yn in
        [Yy]*)
            broadcast script/DeployMultiChainDeployer.s.sol:DeployMultiChainDeployer $CALLDATA $L2_RPC
            ;;
        [Nn]*)
            echo "Exiting..."
            exit 0
            ;;
        esac
        break
        ;;
    new-L1-adapter)
        simulate script/DeployL1OFTAdapter.s.sol:DeployL1OFTAdapter $CALLDATA $L1_RPC_URL
        echo
        read -p "Simulation complete.  Would You like to broadcast the deployment? (y/n)" yn
        case $yn in
        [Yy]*)
            broadcast script/DeployL1OFTAdapter.s.sol:DeployL1OFTAdapter $CALLDATA $L1_RPC_URL
            ;;
        [Nn]*)
            echo "Exiting..."
            exit 0
            ;;
        esac
        break
        ;;
    new-L2-adapter)
        L2_RPC=$(selectLayer2RPC $L2_CHAIN_IDS_ARRAY)
        simulate script/DeployL2OFTAdapter.s.sol:DeployL2OFTAdapter $CALLDATA $L2_RPC
        echo
        read -p "Simulation complete.  Would You like to broadcast the deployment? (y/n)" yn

        case $yn in
        [Yy]*)
            broadcast script/DeployL2OFTAdapter.s.sol:DeployL2OFTAdapter $CALLDATA $L2_RPC
            ;;
        [Nn]*)
            echo "Exiting..."
            exit 0
            ;;
        esac
        break
        echo "Exiting..."
        exit 0
        ;;
    set-peers)
        simulate script/SetPeersOFTAdapter.s.sol:SetPeersOFTAdapter $CALLDATA $L1_RPC_URL

        read -p "Simulation complete.  Would You like to broadcast the deployment? (y/n)" yn

        case $yn in
        [Yy]*)
            broadcast script/SetPeersOFTAdapter.s.sol:SetPeersOFTAdapter $CALLDATA $L1_RPC_URL
            ;;
        [Nn]*)
            echo "Exiting..."
            exit 0
            ;;
        esac
        break
        ;;
    display-help)
        display_help
        exit 0
        ;;
    exit)
        echo "Exiting..."
        exit 0
        ;;
    esac
done
echo "Input json: $INPUT_JSON"
echo "chain id: $L1_CHAIN_ID"
echo "erc20 name: $ERC20_NAME"
echo "deployer acount name: $DEPLOYER_ACCOUNT_NAME"
echo "deployer account address: $DEPLOYER_ADDRESS"
echo "l1 rpc url: $L1_RPC_URL"
echo "L2 rpcs:"
echo "$L2_ENDPOINTS_ARRAY"
exit 0
