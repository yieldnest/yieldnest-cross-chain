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
    "mainnet": "0xfcad670592a3b24869C0b51a6c6FDED4F95D6975"
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

async function verifyRolesAndOwnership(deployment) {
    const chainId = deployment.chainId;
    const networkName = getNetworkName(chainId);
    
    if (networkName === 'fraxtal') {
        console.log('Skipping verification for fraxtal network');
        return;
    }

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
    const expectedOwners = networkName === 'bera' || networkName === 'mainnet' ? deployNo2Owners : deployNo1Owners;
    
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

    console.log(`\n✓ All verifications passed for ${networkName}`);
}

async function main() {
    console.log('Starting ownership and admin role verifications...');
    
    // Read and parse deployment file
    const deploymentPath = 'deployments/ynETHx-1-v0.0.1.json';
    const deploymentJson = JSON.parse(fs.readFileSync(deploymentPath)).chains;

    // Verify each deployment
    for (const [chainId, deployment] of Object.entries(deploymentJson)) {
        console.log(`\nVerifying ${chainId}...`);
        await verifyRolesAndOwnership(deployment);
    }

    console.log('\nAll verifications completed successfully');
}

// Execute main function and handle errors
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
