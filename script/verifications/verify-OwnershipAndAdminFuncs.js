const fs = require('fs');
const { ethers } = require('ethers');
const { getNetworkName, getRpcUrl } = require('./chain-data');
const dotenv = require('dotenv');
dotenv.config();

const chainMultisigs = {
    "binance": "0x721688652DEa9Cabec70BD99411EAEAB9485d436",
    "fraxtal": "0x3F95ce491748a3E04755332c8d52Ec4F02deE096", 
    "taiko": "0x3F95ce491748a3E04755332c8d52Ec4F02deE096",
    "linea": "0xCb343bF07E72548349f506593336b6CB698Ad6dA",
    "blast": "0xCb343bF07E72548349f506593336b6CB698Ad6dA",
    "base": "0xCb343bF07E72548349f506593336b6CB698Ad6dA",
    "scroll": "0xCb343bF07E72548349f506593336b6CB698Ad6dA",
    "arbitrum": "0xCb343bF07E72548349f506593336b6CB698Ad6dA",
    "mantle": "0xCb343bF07E72548349f506593336b6CB698Ad6dA",
    "optimism": "0xCb343bF07E72548349f506593336b6CB698Ad6dA",
    "bera": "0xae495b70D00C724e5a9E23F4613d5e8139677503",
    "mainnet": "0xfcad670592a3b24869C0b51a6c6FDED4F95D6975",
    "hemi": "0x54d4F70a7a8f4E5209F8B21cC4e88440B9192160",
    "ink": "0x5848af047b56F7FCc9DFEAC2F535d4800069E9E1",
    "plasma": "0x10ed81577c75A916BE953F072a18CCd7F33a1bFD",
    "xlayer": "0x5848af047b56F7FCc9DFEAC2F535d4800069E9E1",
    "plume": "0x481aEa2a7B140587907A6a47E69C2D56e28F42c9",
    "avax": "0x67894Cb1C01B8c94F080Df88Dd7F8FB1cc078F7E",
    "polygon": "0xF5b820491A3bfb3F6fAE01421Bd3A6B7Cae483c1"
};


const deployNo1Owners = [
    "0x6A7Ff17e8347e7EAd5856c83299ACb506Cb878b3",
    "0xA225600152a2f640c2274757C4d48a45696f874c", 
    "0xDD62d882ca6bE24d08D0067A4660d9165eb9F80C",
    "0xF522712DdAb999493D716eD681D8a0fb5C5FdC90",
    "0x92cfFf81BD9D3ca540d3ee7e7d26A67b47FdB7c8"
];

const deployNo2Owners = [
    "0xE27B5c80DE762cd47f824515f845CB4bec881F88",
    "0x6A7Ff17e8347e7EAd5856c83299ACb506Cb878b3",
    "0xDD62d882ca6bE24d08D0067A4660d9165eb9F80C", 
    "0xF522712DdAb999493D716eD681D8a0fb5C5FdC90",
    "0x92cfFf81BD9D3ca540d3ee7e7d26A67b47FdB7c8"
];

async function verifyRolesAndOwnership(deployment, sourceNetwork, deployerAddress) {
    const chainId = deployment.chainId;
    const networkName = getNetworkName(chainId);
    
    const rpc = getRpcUrl(chainId);
    const provider = new ethers.providers.JsonRpcProvider(rpc);

    // Get the timelock contract
    const timelock = new ethers.Contract(
        deployment.oftAdapterTimelock,
        [
            'function hasRole(bytes32 role, address account) view returns (bool)',
            'function EXECUTOR_ROLE() view returns (bytes32)',
            'function PROPOSER_ROLE() view returns (bytes32)',
            'function CANCELLER_ROLE() view returns (bytes32)',
            'function DEFAULT_ADMIN_ROLE() view returns (bytes32)',
            'function getMinDelay() view returns (uint256)'
        ],
        provider
    );

    console.log(`\nNetwork: ${networkName}`);

    // Get the multisig contract
    const multisig = new ethers.Contract(
        chainMultisigs[networkName],
        [
            'function getOwners() view returns (address[])'
        ],
        provider
    );

    // Check timelock roles
    const msigAddress = chainMultisigs[networkName];
    const roles = [
        await timelock.DEFAULT_ADMIN_ROLE(),
        await timelock.EXECUTOR_ROLE(), 
        await timelock.PROPOSER_ROLE(),
        await timelock.CANCELLER_ROLE()
    ];

    console.log(`\nVerifying roles for ${networkName}...`);
    
    for (const role of roles) {
        const hasRole = await timelock.hasRole(role, msigAddress);
        if (!hasRole) {
            throw new Error(`Multisig ${msigAddress} does not have role ${role} on timelock for ${networkName}`);
        }
        console.log(`✓ Multisig has role ${role}`);
    }

    const minDelay = await timelock.getMinDelay();
    // Verify that the timelock delay is set to 24 hours (86400 seconds)
    const expectedDelay = 86400; // 24 hours in seconds
    if (minDelay.toString() !== expectedDelay.toString()) {
        throw new Error(`Timelock delay is not set to 24 hours. Current delay: ${minDelay} seconds, expected: ${expectedDelay} seconds`);
    }
    console.log(`✓ Timelock delay correctly set to 24 hours (${expectedDelay} seconds)`);

    // Check multisig owners
    const owners = await multisig.getOwners();
    const expectedOwners = networkName === 'bera' || networkName === 'mainnet' || networkName === 'hemi' || networkName === 'ink' ? deployNo2Owners : deployNo1Owners;
    
    console.log(`\nVerifying multisig owners for ${networkName}...`);
    
    if (owners.length !== expectedOwners.length) {
        throw new Error(`Incorrect number of owners for ${networkName} multisig`);
    }

    for (const owner of expectedOwners) {
        if (!owners.map(a => a.toLowerCase()).includes(owner.toLowerCase())) {
            throw new Error(`Missing owner ${owner} on ${networkName} multisig`);
        }
        console.log(`✓ Found owner ${owner}`);
    }
    {
        // Verify proxy admin is correctly set in storage
        console.log('\nVerifying proxy admin storage slots...');
        
        // Admin slot constant as defined in TransparentUpgradeableProxy
        const ADMIN_SLOT = '0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103';
        
        // Function to verify proxy admin storage slot
        async function verifyProxyAdminStorageSlot(proxyAddress, expectedAdminAddress, proxyName) {
            const proxyAdminFromStorage = await provider.getStorageAt(proxyAddress, ADMIN_SLOT);
            const proxyAdminAddress = ethers.utils.getAddress('0x' + proxyAdminFromStorage.slice(26));
            
            if (proxyAdminAddress.toLowerCase() !== expectedAdminAddress.toLowerCase()) {
                throw new Error(`${proxyName} proxy admin storage slot mismatch. Expected: ${expectedAdminAddress}, Found: ${proxyAdminAddress}`);
            }
            console.log(`✓ ${proxyName} proxy admin storage slot correctly set to ${proxyAdminAddress}`);
        }


        // Implementation slot constant as defined in ERC1967Upgrade
        const IMPLEMENTATION_SLOT = '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc';
        
        // Function to verify proxy implementation storage slot
        async function verifyProxyImplementationStorageSlot(proxyAddress, expectedImplementationAddress, proxyName) {
            const implementationFromStorage = await provider.getStorageAt(proxyAddress, IMPLEMENTATION_SLOT);
            const implementationAddress = ethers.utils.getAddress('0x' + implementationFromStorage.slice(26));
            
            if (implementationAddress.toLowerCase() !== expectedImplementationAddress.toLowerCase()) {
                throw new Error(`${proxyName} implementation storage slot mismatch. Expected: ${expectedImplementationAddress}, Found: ${implementationAddress}`);
            }
            console.log(`✓ ${proxyName} implementation storage slot correctly set to ${implementationAddress}`);
        }
        
        // Check ERC20 proxy admin storage slot
        if (networkName !== getNetworkName(sourceNetwork[0])) {
            await verifyProxyAdminStorageSlot(
                deployment.erc20Address,
                deployment.erc20ProxyAdmin,
                'ERC20'
            );
        }
        
        // Check OFT adapter proxy admin storage slot
        await verifyProxyAdminStorageSlot(
            deployment.oftAdapter,
            deployment.oftAdapterProxyAdmin,
            'OFT adapter'
        );

        // Check OFT adapter implementation storage slot
        await verifyProxyImplementationStorageSlot(
            deployment.oftAdapter,
            deployment.oftAdapterImplementation,
            'OFT adapter'
        );
        
        // Check ERC20 implementation storage slot
        await verifyProxyImplementationStorageSlot(
            deployment.erc20Address,
            deployment.erc20Implementation,
            'ERC20'
        );
                
    }

    // Check proxy admin ownership
    const erc20ProxyAdmin = new ethers.Contract(
        deployment.erc20ProxyAdmin,
        ['function owner() view returns (address)'],
        provider
    );

    const oftProxyAdmin = new ethers.Contract(
        deployment.oftAdapterProxyAdmin,
        ['function owner() view returns (address)'],
        provider
    );

    console.log('\nVerifying proxy admin ownership...');


    if (networkName !== getNetworkName(sourceNetwork[0])) {
        const erc20ProxyAdminOwner = await erc20ProxyAdmin.owner();
        if (erc20ProxyAdminOwner.toLowerCase() !== deployment.oftAdapterTimelock.toLowerCase()) {
            throw new Error(`ERC20 proxy admin not owned by timelock. Owner: ${erc20ProxyAdminOwner}`);
        }
        console.log('✓ ERC20 proxy admin owned by timelock');
    }

    const oftProxyAdminOwner = await oftProxyAdmin.owner();
    if (oftProxyAdminOwner.toLowerCase() !== deployment.oftAdapterTimelock.toLowerCase()) {
        throw new Error(`OFT proxy admin not owned by timelock. Owner: ${oftProxyAdminOwner}`);
    }
    console.log('✓ OFT proxy admin owned by timelock');

    // Check DEFAULT_ADMIN_ROLE on ERC20 and proxy admin
    const DEFAULT_ADMIN_ROLE = '0x0000000000000000000000000000000000000000000000000000000000000000';
    
    const erc20 = new ethers.Contract(
        deployment.erc20Address,
        ['function hasRole(bytes32 role, address account) view returns (bool)'],
        provider
    );

    console.log('\nVerifying DEFAULT_ADMIN_ROLE ownership...');
    if (networkName !== getNetworkName(sourceNetwork[0])) {
        const erc20HasAdminRole = await erc20.hasRole(DEFAULT_ADMIN_ROLE, chainMultisigs[networkName]);
        if (!erc20HasAdminRole) {
            throw new Error('ERC20 DEFAULT_ADMIN_ROLE not owned by Multisig');
        }
        console.log('✓ ERC20 DEFAULT_ADMIN_ROLE owned by Multisig');
    }

    // Check that deployer address does not have DEFAULT_ADMIN_ROLE on ERC20    
    if (networkName !== getNetworkName(sourceNetwork[0])) {
        const deployerHasAdminRole = await erc20.hasRole(DEFAULT_ADMIN_ROLE, deployerAddress);
        if (deployerHasAdminRole) {
            throw new Error(`Deployer address ${deployerAddress} still has DEFAULT_ADMIN_ROLE on ERC20 - this should be revoked`);
        }
        console.log('✓ Deployer address does not have DEFAULT_ADMIN_ROLE on ERC20');
    }

    const oftAdapter = new ethers.Contract(
        deployment.oftAdapter,
        ['function owner() view returns (address)'],
        provider
    );

    const oftAdapterOwner = await oftAdapter.owner();
    if (oftAdapterOwner.toLowerCase() !== chainMultisigs[networkName].toLowerCase()) {
        throw new Error(`OFT adapter not owned by Multisig. Owner: ${oftAdapterOwner}`);
    } else {
        console.log('✓ OFT adapter owned by Multisig');
    }


    console.log(`\n✓ All verifications passed for ${networkName}`);
}

async function main() {
    console.log('Starting ownership and admin role verifications...');
    
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

    // Find source network by checking which chain has multiChainDeployer set to 0x0
    const deploymentData = JSON.parse(fs.readFileSync(deploymentPath)).chains;
    const sourceNetwork = Object.entries(deploymentData).find(
        ([_, data]) => data.isL1 === true
    );

    if (!sourceNetwork) {
        throw new Error("Could not find source network - no chain marked as L1");
    }

    const [sourceChainId, sourceData] = sourceNetwork;
    const networkName = getNetworkName(parseInt(sourceChainId));
    console.log('Source network chain ID:', sourceChainId);
    console.log('Source network name:', networkName);

    // Read and parse deployment file
    const deploymentJson = JSON.parse(fs.readFileSync(deploymentPath)).chains;
    const deployerAddress = JSON.parse(fs.readFileSync(deploymentPath)).deployerAddress;
    // Verify each deployment
    for (const [chainId, deployment] of Object.entries(deploymentJson)) {
        console.log(`\nVerifying ${chainId}...`);
        await verifyRolesAndOwnership(deployment, sourceNetwork, deployerAddress);
    }

    console.log('\nAll verifications completed successfully');
}

// Execute main function and handle errors
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
