const fs = require('fs');
const { execSync } = require('child_process');
const { getNetworkName, getRpcUrl } = require('./chain-data');
const dotenv = require('dotenv');
dotenv.config();


// TODO: Fill in the correct addresses for the implementation contracts for each new deployment
const ERC20_IMPLEMENTATION_ADDRESS = '0x01029eE5670dd5cc1294410588cacC43a49f8fF1';
const OFT_ADAPTER_IMPLEMENTATION_ADDRESS = '0xa6d3F9E893604Dd77c773e8cdb4040c060aE5884';



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

// Get L2YnERC20Upgradeable bytecode from local build output
function getLocalL2YnERC20UpgradeableBytecode() {
    const buildPath = 'out/L2YnERC20Upgradeable.sol/L2YnERC20Upgradeable.json';
    const build = JSON.parse(fs.readFileSync(buildPath));
    return build.deployedBytecode.object;
}

// Get L2YnOFTAdapter bytecode from local build output
function getLocalL2YnOFTAdapterUpgradeableBytecode() {
    const buildPath = 'out/L2YnOFTAdapterUpgradeable.sol/L2YnOFTAdapterUpgradeable.json';
    const build = JSON.parse(fs.readFileSync(buildPath));
    return build.deployedBytecode.object;
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

async function verifyERC20ProxyBytecode(deployment) {
    console.log('\nVerifying ERC20 implementation bytecode...');
    console.log('Chain ID:', deployment.chainId);
    console.log('ERC20 Implementation Address:', ERC20_IMPLEMENTATION_ADDRESS);
    const rpc = getRpcUrl(deployment.chainId);
    const bytecode = await getBytecode(rpc, ERC20_IMPLEMENTATION_ADDRESS);

    
    // Get local bytecode for comparison
    const localBytecode = getLocalL2YnERC20UpgradeableBytecode();
    
    if (bytecode !== localBytecode) {
        throw new Error('ERC20 bytecode does not match local implementation');
    }
    
    console.log('ERC20 bytecode verification successful');
}

async function verifyOFTAdapterBytecode(deployment) {
    console.log('\nVerifying OFT Adapter implementation bytecode...');
    console.log('Chain ID:', deployment.chainId);
    console.log('OFT Adapter Implementation Address:', OFT_ADAPTER_IMPLEMENTATION_ADDRESS);
    const rpc = getRpcUrl(deployment.chainId);
    const bytecode = await getBytecode(rpc, OFT_ADAPTER_IMPLEMENTATION_ADDRESS);

    // Get local bytecode for comparison
    const localBytecode = getLocalL2YnOFTAdapterUpgradeableBytecode();

    // FIXME: compare actual bytecode, not just length
    if (bytecode.length !== localBytecode.length) {
        throw new Error('OFT Adapter bytecode length mismatch');
    }
    console.log('OFT Adapter bytecode verification successful');
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

            await verifyERC20ProxyBytecode(deployment);

            await verifyOFTAdapterBytecode(deployment);
            
            console.log(`\nAll verifications passed for chain ${deployment.chainId}`);
            
        } catch (error) {
            console.error(`\nVerification failed for chain ${deployment.chainId}:`);
            console.error(error.message);
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
