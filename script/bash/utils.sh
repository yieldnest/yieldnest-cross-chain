
###############
## FUNCTIONS ##
###############

function simulate() {
    forge script $1 --sig $2 --rpc-url $3 --account $DEPLOYER_ACCOUNT_NAME --sender $DEPLOYER_ADDRESS
}

function broadcast() {
    defaultArgs=("--sig" "$2" "--rpc-url" "$3" "--account" "$DEPLOYER_ACCOUNT_NAME" "--sender" "$DEPLOYER_ADDRESS" "--broadcast" "--verify" "--slow" "--password" "$PASSWORD")
    
    if [[ $3 == "arbitrum" || $3 == "scroll" ]]; then
        forge script "$1" "${defaultArgs[@]}" --verifier blockscout --verifier-url "https://$3.blockscout.com/api/"
    elif [[ $3 == "bera" ]]; then
        forge script "$1" "${defaultArgs[@]}" --verifier custom --verifier-url "https://api.routescan.io/v2/network/mainnet/evm/80094/etherscan/api"
    elif [[ $3 == "morph_testnet" ]]; then
        forge script "$1" "${defaultArgs[@]}" --verifier blockscout --with-gas-price 0.03gwei --priority-gas-price 0.03gwei --verifier-url "https://explorer-api-holesky.morphl2.io/api?" --chain 2810
    elif [[ $3 == "binance" ]]; then
        forge script "$1" "${defaultArgs[@]}" --verifier etherscan --verifier-url "https://api.bscscan.com/api" --verifier-api-key "$BSCSCAN_API_KEY" --chain 56
    elif [[ $3 == "hemi" ]]; then
        forge script "$1" "${defaultArgs[@]}" --verifier blockscout --verifier-url "https://explorer.hemi.xyz/api" --chain 43111
    elif [[ $3 == "ink" ]]; then
        forge script "$1" "${defaultArgs[@]}" --verifier blockscout --verifier-url "https://explorer.inkonchain.com/api" --chain 57073
    else
        forge script "$1" "${defaultArgs[@]}" --etherscan-api-key "$4"
    fi
}


# Function to handle errors
function error_exit() {
    echo "Error: $1" >&2
    usage
    exit 1
}

BROADCAST=false
SIMULATE_ONLY=false
SKIP_L1=false

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

function delimiter() {
    echo ""
    echo "###################################################"
    echo ""
}

