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
    56: "binance",
    43111: "hemi",
    57073: "ink",
    6900: "nibiru",
    196: "xLayer",
    9745: "plasma",
    98866: "plume",
    43114: "avax",
    137: "polygon",
    50: "xdc",
    747474: "katana"
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

// Get scan API key for a chain ID using environment variables
function getScanApiKey(chainId) {
    let networkName = getNetworkName(chainId);
    if (!networkName) {
        throw new Error(`No network name found for chain ID ${chainId}`);
    }
    
    // Convert network names for scan API keys
    networkName = networkName === 'binance' ? 'bsc' : networkName;
    networkName = networkName === 'mainnet' ? 'ether' : networkName;
    // Convert network name to uppercase and append SCAN_API_KEY for env var name
    const envVarName = `${networkName.toUpperCase()}SCAN_API_KEY`;
    const apiKey = process.env[envVarName];
    
    if (!apiKey) {
        throw new Error(`No scan API key found in environment variable ${envVarName}`);
    }
    
    return apiKey;
}




module.exports = {
    getNetworkName,
    getRpcUrl,
    getScanApiKey
};

