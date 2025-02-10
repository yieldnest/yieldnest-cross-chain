const fs = require('fs');
const { execSync } = require('child_process');
const { getNetworkName } = require('./chain-data');
const dotenv = require('dotenv');
dotenv.config();



// Helper to execute curl command and get bytecode
async function getBytecode(rpc, address) {
    const cmd = `curl -s --location ${rpc} \
        --header 'Content-Type: application/json' \
        --data '{"method":"eth_getCode", "params":["${address}","latest"], "id":1, "jsonrpc":"2.0"}' \
        | jq -r .result`;
    
    return execSync(cmd).toString().trim();
}

// Parse bytecode into parts
function parseBytecode(bytecode) {
    return {
        preamble: bytecode.substring(0, 58),
        owner: bytecode.substring(58, 98), 
        suffix: bytecode.substring(98)
    };
}

// Get proxy bytecode from local build output
function getLocalTransparentUpgradeableProxyBytecode() {
    const proxyBuildPath = 'out/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json';
    const proxyBuild = JSON.parse(fs.readFileSync(proxyBuildPath));
    return proxyBuild.deployedBytecode.object;
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


// Verify bytecode parts
async function verifyProxyBytecode(deployment, proxyKey, proxyAdminKey) {
    
    // Get proxy admin address from deployment
    const proxyAdmin = deployment[proxyAdminKey];
    
    // Get RPC URL based on chainId
    const chainId = deployment.chainId;
    const rpc = getRpcUrl(chainId); // You'll need to implement getRpcUrl based on your RPC mapping
    
    // Get bytecode for OFT adapter
    const bytecode = await getBytecode(rpc, deployment[proxyKey]);
    const parts = parseBytecode(bytecode);
    
    // Get local bytecode for comparison
    const localBytecode = getLocalTransparentUpgradeableProxyBytecode();
    const localParts = parseBytecode(localBytecode);
    
    // Verify preamble and suffix match
    if (parts.preamble !== localParts.preamble) {
        throw new Error('Preamble mismatch between local and on-chain bytecode');
    }
    
    if (parts.suffix !== localParts.suffix) {
        throw new Error('Suffix mismatch between local and on-chain bytecode'); 
    }
    
    // Verify owner is proxy admin
    if ('0x' + parts.owner.toLowerCase() !== proxyAdmin.toLowerCase()) {
        throw new Error('Owner in bytecode does not match proxy admin');
    }
    
    console.log('Bytecode verification successful');
    console.log('Preamble:', parts.preamble);
    console.log('Owner:', parts.owner);
    console.log('Suffix length:', parts.suffix.length);
}

// Main verification function
async function main() {
    // Read all deployment files from deployments directory
    const deployments = JSON.parse(fs.readFileSync('deployments/ynETHx-1-v0.0.1.json')).chains;
    
    // Get all chain IDs from deployment
    const chainIds = Object.keys(deployments).filter(key => !isNaN(key));

    console.log('\nStarting bytecode verification...');
    console.log('Found chain IDs:', chainIds);
    console.log('Deployment file:', 'deployments/ynETHx-1-v0.0.1.json');
    
    for (const chainId of chainIds) {
        const deployment = deployments[chainId];
        
        // Skip chain ID 1 (mainnet)
        if (deployment.chainId === 1) continue;
        
        console.log(`\nVerifying bytecode for chain ${deployment.chainId}...`);
        
        try {
            // Verify ERC20 proxy
            console.log('\nVerifying ERC20 proxy bytecode...');
            await verifyProxyBytecode(
                deployment,
                'erc20Address',
                'erc20ProxyAdmin'
            );
            
            // Verify OFT adapter proxy
            console.log('\nVerifying OFT adapter proxy bytecode...');
            await verifyProxyBytecode(
                deployment,
                'oftAdapter',
                'oftAdapterProxyAdmin'
            );
            
            console.log(`\nAll verifications passed for chain ${deployment.chainId}`);
            
        } catch (error) {
            console.error(`\nVerification failed for chain ${deployment.chainId}:`);
            console.error(error.message);
        }

        // Break if not chain ID 1
        if (chainId !== '1') {
            console.log('Skipping non-mainnet chain');
            break;
        }
    }
}

// Run if called directly
if (require.main === module) {
    main().catch(console.error);
}


// Export verification function
module.exports = {
    verifyProxyBytecode
};
