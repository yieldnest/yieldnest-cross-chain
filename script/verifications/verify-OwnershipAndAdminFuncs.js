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
    "hemi": "0x54d4F70a7a8f4E5209F8B21cC4e88440B9192160"
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

async function verifyRolesAndOwnership(deployment, sourceNetwork) {
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
            'function DEFAULT_ADMIN_ROLE() view returns (bytes32)'
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

    // Check multisig owners
    const owners = await multisig.getOwners();
    const expectedOwners = networkName === 'bera' || networkName === 'mainnet' || networkName === 'hemi' ? deployNo2Owners : deployNo1Owners;
    
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

    // Verify each deployment
    for (const [chainId, deployment] of Object.entries(deploymentJson)) {
        console.log(`\nVerifying ${chainId}...`);
        await verifyRolesAndOwnership(deployment, sourceNetwork);
    }

    console.log('\nAll verifications completed successfully');
}

// Execute main function and handle errors
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
