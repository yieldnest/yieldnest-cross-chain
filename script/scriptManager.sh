#!/bin/bash
source .env

set -e

echo "EXECUTING"
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
    forge script $1 -s $2 --rpc-url $3 --account $DEPLOYER_ACCOUNT_NAME --sender $DEPLOYER_ADDRESS --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify
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

function deployMultiChainDeployer() {
    echo "$1 $2"
    # call simulation
    simulate script/DeployMultiChainDeployer.s.sol:DeployMultiChainDeployer $1 $2
    read -p "Simulation Complete would you like to deploy the MultiChainDeployer? (y/n) " yn
    case $yn in
    [Yy]*)
        broadcast script/DeployMultiChainDeployer.s.sol:DeployMultiChainDeployer $1 $2
        ;;
    [Nn]*) ;;

    esac

}

function selectLayer2RPC() {
    local L2_RPC_URL=''
    local CHAIN_ID_ARRAY=$1
    if [[ "${#CHAIN_ID_ARRAY[@]}" == 1 ]]; then
        L2_RPC_URL="${L2_ENDPOINTS_ARRAY[0]}"
    else
        echo "Please enter the Chain Id you would like to deploy on."
        echo "Chain ids: ${CHAIN_ID_ARRAY[@]}"
        read -p "enter chain id: " $SELECTED_CHAIN
        arrayIndex=$(searchArray $SELECTED_CHAIN $CHAIN_ID_ARRAY)
        L2_RPC_URL="${L2_ENDPOINTS_ARRAY[${arrayIndex}]}"
        if [[ -z $L2_RPC_URL ]]; then
            echo "Chain RPC not ound for $SELECTED_CHAIN"
            exit 1
        fi
    fi
    #exit if no url is found
    if [[ -z $L2_RPC_URL ]]; then
        exit 1
    fi
    echo $L2_RPC_URL

}

function findL2RPC() {
    local L2_RPC_URL=''
    local CHAIN_ID_ARRAY=$1

    arrayIndex=$(searchArray $2 $CHAIN_ID_ARRAY)
    L2_RPC_URL="${L2_ENDPOINTS_ARRAY[${arrayIndex}]}"
    if [[ -z $L2_RPC_URL ]]; then
        echo "Chain RPC not ound for $2"
        exit 1
    fi

    #exit if no url is found
    if [[ -z $L2_RPC_URL ]]; then
        exit 1
    fi
    echo $L2_RPC_URL
}

function checkInput() {
    if [[ -z $2 || $2 == -* ]]; then
        error_exit "Missing value for parameter $1"
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
    echo "getting endpoints..."
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

# forge script script/DeployL1OFTAdapter.s.sol:DeployL1OFTAdapter \
# --rpc-url ${rpc} --sig "run(string calldata)" ${path} \
# --account ${deployerAccountName} --sender ${deployer} \
# --broadcast --etherscan-api-key ${api} --verify

CALLDATA=$(cast calldata "run(string)" "/$FILE_PATH")

#if there is an output json file get the adapter address
if [[ -f "$OUTPUT_JSON_PATH" ]]; then
    L1_ADAPTER_ADDRESS=$(jq -r '.chains.["'"$L1_CHAIN_ID"'"].oftAdapter' "$OUTPUT_JSON_PATH")
fi
echo "$L1_ADAPTER_ADDRESS"
# if there is no l1 adapter address in the deployment file, deploy the l1 adapter
if [[ -z "$L1_ADAPTER_ADDRESS" || "$L1_ADAPTER_ADDRESS" == "null" || "$L1_ADAPTER_ADDRESS" == "0x0000000000000000000000000000000000000000" ]]; then
    echo "DEPLOYING MultiChain Deployers..."
    #deploy multichainDeployer to L2s that don't have it
    for l2 in $L2_CHAIN_IDS_ARRAY; do
        if [[ -f "$OUTPUT_JSON_PATH" ]]; then
            deployerAddress=$(jq -r '.chains.["'"$l2"'"].multiChainDeployer' "$OUTPUT_JSON_PATH")
        fi
        # if there is no deployed deployer then deploy a deployer
        if [[ -z "$deployerAddress" || "$deployerAddress" == "null" || "$deployerAddress" == "0x0000000000000000000000000000000000000000" ]]; then
            L2_RPC=$(findL2RPC $L2_CHAIN_IDS_ARRAY $l2)
            echo "Deploying deployer on chainId: $l2"
            deployMultiChainDeployer $CALLDATA $L2_RPC
        fi
    done

    if [[ -f "$OUTPUT_JSON_PATH" ]]; then
        echo "getting l2 adapter address..."
        L2_RPC=$(findL2RPC "${L2_CHAIN_IDS_ARRAY[0]}" $L2_CHAIN_IDS_ARRAY)
        #simulate and get l2 adapter address
        L2_ADAPTER_ADDRESS=$(simulate script/DeployL2OFTAdapter.s.sol:DeployL2OFTAdapter $CALLDATA $L2_RPC | grep -oP 'L2 OFT Adapter deployed at:\s+\K0x[a-fA-F0-9]{40}')
        # | grep -oP 'L2 OFT Adapter deployed at:\s+\K0x[a-fA-F0-9]{40}'
        echo "Predicted L2 Adapter Address: $L2_ADAPTER_ADDRESS"
        # Use jq to modify the predictedL2AdapterAddress in input JSON and save to the output file
        newJson=$(jq '.predictedL2AdapterAddress = "'"$L2_ADAPTER_ADDRESS"'"' "$FILE_PATH")
        echo -E "${newJson}" >"$FILE_PATH"

    fi

    #deploy l1 and call setPeer for l2 adapters
    simulate script/DeployL1OFTAdapter.s.sol:DeployL1OFTAdapter $CALLDATA $L1_RPC_URL
    echo
    read -p "Simulation complete.  Would You like to broadcast the deployment? (y/n) " yn
    case $yn in
    [Yy]*)
        broadcast script/DeployL1OFTAdapter.s.sol:DeployL1OFTAdapter $CALLDATA $L1_RPC_URL
        ;;
    [Nn]*)
        echo "Exiting..."
        exit 0
        ;;
    esac
    #deploy l2's and call setPeers for l1 and other l2's

    exit 1

    # check that there is a contract at the stored address
fi

# clear
# echo "What would you like to deploy?"
# select deployOptions in new-MultiChainDeployer new-L1-adapter new-L2-adapter set-peers display-help exit; do
#     case $deployOptions in
#     new-MultiChainDeployer)
#         L2_RPC=$(selectLayer2RPC $L2_CHAIN_IDS_ARRAY)
#         # call simulation
#         simulate script/DeployMultiChainDeployer.s.sol:DeployMultiChainDeployer $CALLDATA $L2_RPC
#         echo
#         read -p "Simulation complete.  Would You like to broadcast the deployment? (y/n) " yn
#         case $yn in
#         [Yy]*)
#             broadcast script/DeployMultiChainDeployer.s.sol:DeployMultiChainDeployer $CALLDATA $L2_RPC
#             ;;
#         [Nn]*)
#             echo "Exiting..."
#             exit 0
#             ;;
#         esac
#         break
#         ;;
#     new-L1-adapter)
#         simulate script/DeployL1OFTAdapter.s.sol:DeployL1OFTAdapter $CALLDATA $L1_RPC_URL
#         echo
#         read -p "Simulation complete.  Would You like to broadcast the deployment? (y/n) " yn
#         case $yn in
#         [Yy]*)
#             broadcast script/DeployL1OFTAdapter.s.sol:DeployL1OFTAdapter $CALLDATA $L1_RPC_URL
#             ;;
#         [Nn]*)
#             echo "Exiting..."
#             exit 0
#             ;;
#         esac
#         break
#         ;;
#     new-L2-adapter)
#         L2_RPC=$(selectLayer2RPC $L2_CHAIN_IDS_ARRAY)
#         simulate script/DeployL2OFTAdapter.s.sol:DeployL2OFTAdapter $CALLDATA $L2_RPC
#         echo
#         read -p "Simulation complete.  Would You like to broadcast the deployment? (y/n) " yn

#         case $yn in
#         [Yy]*)
#             broadcast script/DeployL2OFTAdapter.s.sol:DeployL2OFTAdapter $CALLDATA $L2_RPC
#             ;;
#         [Nn]*)
#             echo "Exiting..."
#             exit 0
#             ;;
#         esac
#         break
#         echo "Exiting..."
#         exit 0
#         ;;
#     set-peers)

#         L2_RPC=$(selectLayer2RPC $L2_CHAIN_IDS_ARRAY)

#         PEER_CALLDATA=$(cast calldata "getPeerData(string calldata)" "/$FILE_PATH")
#         echo "simulating transaction... "
#         SIMULATION=$(simulate script/SetPeersOFTAdapter.s.sol:SetPeersOFTAdapter $CALLDATA $L2_RPC)
#         echo "$SIMULATION"

#         if [[ $SIMULATION == *"OFT Adapter not deployed yet"* ]]; then
#             clear
#             echo
#             echo "Please deploy the OFT adapter before setting peers."
#             echo
#             exit 0
#         fi

#         read -p "Simulation complete.  Would You like to get the calldata or broadcast the deployment? (calldata/broadcast) " yn

#         case $yn in
#         callData | c | CallData | calldata)
#             TX_DATA=$(simulate script/SetPeersOFTAdapter.s.sol:SetPeersOFTAdapter $PEER_CALLDATA $L2_RPC)
#             echo "$TX_DATA"
#             ;;
#         broadcast | b | BroadCast | Broadcast | broadCast)
#             cast calldata script/SetPeersOFTAdapter.s.sol:SetPeersOFTAdapter $CALLDATA $L2_RPC
#             ;;
#         esac
#         break
#         ;;
#     display-help)
#         display_help
#         exit 0
#         ;;
#     exit)
#         echo "Exiting..."
#         exit 0
#         ;;
#     esac
# done

echo "Script Complete..."
exit 0
