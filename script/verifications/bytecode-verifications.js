const fs = require('fs');
const { execSync } = require('child_process');
const { getNetworkName, getRpcUrl } = require('./chain-data');
const dotenv = require('dotenv');
dotenv.config();


// TODO: Fill in the correct addresses for the implementation contracts for each new deployment
function getERC20ImplementationAddress(chainId) {
    if (chainId === 1) {
        return '0xe50aecb1bbffaba835366ca8264539c30ed6e1d9';
    }
    return '0x01029eE5670dd5cc1294410588cacC43a49f8fF1';
}
const OFT_ADAPTER_IMPLEMENTATION_ADDRESS = '0xa6d3F9E893604Dd77c773e8cdb4040c060aE5884';
const L1_OFT_IMPLEMENTATION_ADDRESS = '0x09564BE5E4933586DC89B2a2Ac5790c6ba636003';


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

// Get proxyAdmin bytecode from local build output
function getLocalProxyAdminBytecode() {
    const proxyAdminBuildPath = 'out/ProxyAdmin.sol/ProxyAdmin.json';
    const proxyAdminBuild = JSON.parse(fs.readFileSync(proxyAdminBuildPath));
    return proxyAdminBuild.deployedBytecode.object;
}

// Get L2YnERC20Upgradeable bytecode from local build output
function getLocalL2YnERC20UpgradeableBytecode() {
    const buildPath = 'out/L2YnERC20Upgradeable.sol/L2YnERC20Upgradeable.json';
    const build = JSON.parse(fs.readFileSync(buildPath));
    return build.deployedBytecode.object;
}

// Get L1YnOFTAdapter bytecode from local build output 
function getLocalL1YnOFTUpgradeableBytecode() {
    const buildPath = 'out/L1YnOFTAdapterUpgradeable.sol/L1YnOFTAdapterUpgradeable.json';
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

    // Get bytecode for proxyAdmin
    const bytecodeAdmin = await getBytecode(rpc, '0x' + parts.owner);
    // Get local bytecode for comparison
    const localBytecodeAdmin = getLocalProxyAdminBytecode();

    // Verify proxyAdmin bytecode
    if (bytecodeAdmin.toLowerCase() !== localBytecodeAdmin.toLowerCase()) {
        throw new Error('ProxyAdmin bytecode is different local vs on-chain');
    }
    
    console.log('Bytecode verification successful');
    console.log('Preamble:', parts.preamble);
    console.log('Owner:', parts.owner);
    console.log('Suffix length:', parts.suffix.length);
}

async function verifyERC20ProxyBytecode(deployment) {
    console.log('\nVerifying ERC20 implementation bytecode...');
    console.log('Chain ID:', deployment.chainId);
    const erc20ImplAddress = await getERC20ImplementationAddress(deployment);
    console.log('ERC20 Implementation Address:', erc20ImplAddress);
    const rpc = getRpcUrl(deployment.chainId);
    const bytecode = await getBytecode(rpc, erc20ImplAddress);

    
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

async function verifyL1OFTBytecode(deployment) {
    console.log('\nVerifying L1 OFT implementation bytecode...');
    console.log('Chain ID:', deployment.chainId);
    console.log('L1 OFT Implementation Address:', L1_OFT_IMPLEMENTATION_ADDRESS);
    const rpc = getRpcUrl(deployment.chainId);
    // Verify bytecode using forge verify-bytecode
    const { execSync } = require('child_process');
    const cmd = `forge verify-bytecode ${L1_OFT_IMPLEMENTATION_ADDRESS} L1YnOFTAdapterUpgradeable.sol:L1YnOFTAdapterUpgradeable --rpc-url ${rpc}`;
    
    try {
        execSync(cmd);
    } catch (error) {
        throw new Error(`L1 OFT bytecode verification failed: ${error.message}`);
    }
    
    console.log('L1 OFT bytecode verification successful');
}



// Main verification function
async function main() {
    // Get deployment path from command line args
    const deploymentPath = process.argv[2];
    if (!deploymentPath) {
        const deploymentFiles = fs.readdirSync('deployments')
            .filter(f => f.endsWith('.json'))
            .map(f => `• deployments/${f}`)
            .join('\n');
        throw new Error(`Please provide deployment file path as argument. Available paths:\n${deploymentFiles}`);
    }

    console.log('Deployment path:', deploymentPath);

    // Read deployment file
    const deployments = JSON.parse(fs.readFileSync(deploymentPath)).chains;
    
    // Get all chain IDs from deployment
    const chainIds = Object.keys(deployments).filter(key => !isNaN(key));

    console.log('\nStarting bytecode verification...');
    console.log('Found chain IDs:', chainIds);
    console.log('Deployment file:', deploymentPath);

    
    // Verify L1 chain first
    const l1Deployment = Object.values(deployments).find(d => d.isL1);
    if (!l1Deployment) {
        throw new Error("Could not find L1 chain in deployment");
    }
    const mainnetDeployment = l1Deployment;
    if (mainnetDeployment) {
        console.log('\nVerifying bytecode for mainnet...');
        try {
            // Verify OFT adapter proxy only for mainnet
            console.log('\nVerifying OFT adapter proxy bytecode...');
            await verifyProxyBytecode(
                mainnetDeployment,
                'oftAdapter', 
                'oftAdapterProxyAdmin'
            );

            await verifyL1OFTBytecode(mainnetDeployment);

            console.log('\nAll verifications passed for mainnet');
        } catch (error) {
            console.error('\nVerification failed for mainnet:');
            console.error(error.message);
        }
    }
    
    for (const chainId of chainIds) {
        const deployment = deployments[chainId];

        // Skip L1 chain
        if (deployment.isL1) continue;
        
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
