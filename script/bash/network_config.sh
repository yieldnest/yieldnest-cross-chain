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
    56)
        echo "binance"
        ;;
    97)
        echo "bsc_testnet"
        ;;
    743111)
        echo "hemi_testnet"
        ;;
    43111)
        echo "hemi"
        ;;
    57073)
        echo "ink"
        ;;
    6900)
        echo "nibiru"
        ;;

    196)
        echo "xLayer"
        ;;
    9745)
        echo "plasma"
        ;;
    98866)
        echo "plume"
        ;;
    43114)
        echo "avax"
        ;;
    137)
        echo "polygon"
        ;;
    50)
        echo "xdc"
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
    56)
        echo "$BSCSCAN_API_KEY"
        ;;
    97)
        echo "$BSCSCAN_API_KEY"
        ;;
    743111)
        echo "$HEMI_API_KEY"
        ;;
    43111)
        echo "$HEMI_API_KEY"
        ;;
    57073)
        echo "$INK_API_KEY"
        ;;
    6900)
        echo "$NIBIRUSCAN_API_KEY"
        ;;
    196)
        echo "$XLAYERSCAN_API_KEY"
        ;;
    9745)
        echo "$PLASMACAN_API_KEY"
        ;;
    98866)
        echo "$PLUMESCAN_API_KEY"
        ;;
    43114)
        echo "$AVAXSCAN_API_KEY"
        ;;
    137)
        echo "$POLYGONSCAN_API_KEY"
        ;;
    50)
        echo "$XDSCAN_API_KEY"
        ;;
    *)
        echo ""
        ;;
    esac
}

