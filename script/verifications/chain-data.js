const chainIdToNetwork = {
    1: "mainnet",
    8453: "base",
    10: "optimism",
    42161: "arbitrum", 
    252: "fraxtal",
    169: "manta",
    167000: "taiko",
    534352: "scroll",
    250: "fantom", 
    5000: "mantle",
    81457: "blast",
    59144: "linea",
    17000: "holesky",
    11155111: "sepolia",
    2810: "morph_testnet",
    2522: "fraxtal_testnet",
    80094: "bera",
    56: "binance"
};

function getNetworkName(chainId) {
    return chainIdToNetwork[chainId] || "";
}

// Get RPC URL for a chain ID using environment variables
function getRpcUrl(chainId) {
    const networkName = getNetworkName(chainId);
    if (!networkName) {
        throw new Error(`No network name found for chain ID ${chainId}`);
    }
    
    // Convert network name to uppercase and append _RPC for env var name
    const envVarName = `${networkName.toUpperCase()}_RPC_URL`;
    const rpcUrl = process.env[envVarName];
    
    if (!rpcUrl) {
        throw new Error(`No RPC URL found in environment variable ${envVarName}`);
    }
    
    return rpcUrl;
}


module.exports = {
    getNetworkName,
    getRpcUrl
};

