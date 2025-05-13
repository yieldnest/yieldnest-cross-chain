# Yieldnest Cross-Chain Contracts

This project contains the smart contracts and scripts for deploying cross-chain Yieldnest tokens using LayerZero technology. It leverages the Foundry development toolkit for testing, building, and deploying contracts, and uses Yarn to manage dependencies.

## Contract Addresses (ynETHx)

### Mainnet Addresses

- Ethereum: [0x657d9ABA1DBb59e53f9F3eCAA878447dCfC96dCb](https://etherscan.io/address/0x657d9ABA1DBb59e53f9F3eCAA878447dCfC96dCb)

### Layer 2 & Sidechain Addresses

- Arbitrum: [0xE231DB5F348d709239Ef1741EA30961B3B635a61](https://arbitrum.blockscout.com/address/0xE231DB5F348d709239Ef1741EA30961B3B635a61)
- Optimism: [0xE231DB5F348d709239Ef1741EA30961B3B635a61](https://optimistic.etherscan.io/address/0xE231DB5F348d709239Ef1741EA30961B3B635a61)
- Base: [0xE231DB5F348d709239Ef1741EA30961B3B635a61](https://basescan.org/address/0xE231DB5F348d709239Ef1741EA30961B3B635a61)
- Fraxtal: [0xE231DB5F348d709239Ef1741EA30961B3B635a61](https://fraxscan.com/address/0xE231DB5F348d709239Ef1741EA30961B3B635a61)
- Scroll: [0xE231DB5F348d709239Ef1741EA30961B3B635a61](https://scroll.blockscout.com/address/0xE231DB5F348d709239Ef1741EA30961B3B635a61)
- Taiko: [0xE231DB5F348d709239Ef1741EA30961B3B635a61](https://taikoscan.io/address/0xE231DB5F348d709239Ef1741EA30961B3B635a61)
- Mantle: [0xE231DB5F348d709239Ef1741EA30961B3B635a61](https://mantlescan.info/address/0xE231DB5F348d709239Ef1741EA30961B3B635a61)
- Blast: [0xE231DB5F348d709239Ef1741EA30961B3B635a61](https://blastscan.io/address/0xE231DB5F348d709239Ef1741EA30961B3B635a61)
- Bera: [0xE231DB5F348d709239Ef1741EA30961B3B635a61](https://beratrail.io/address/0xE231DB5F348d709239Ef1741EA30961B3B635a61)
- BNB Chain: [0xE231DB5F348d709239Ef1741EA30961B3B635a61](https://bscscan.com/address/0xE231DB5F348d709239Ef1741EA30961B3B635a61)

## Contract Addresses (ynBTCk)

### Mainnet Addresses

- BNB Chain: [0x78839cE14a8213779128Ee4da6D75E1326606A56](https://bscscan.com/address/0x78839cE14a8213779128Ee4da6D75E1326606A56)

### Layer 2 & Sidechain Addresses

- Ethereum: [0x68589adc7687A23Ff2B06fb032b997f09B44Ed5d](https://etherscan.io/address/0x68589adc7687A23Ff2B06fb032b997f09B44Ed5d)
- Arbitrum: [0x68589adc7687A23Ff2B06fb032b997f09B44Ed5d](https://arbiscan.io/address/0x68589adc7687A23Ff2B06fb032b997f09B44Ed5d)
- Optimism: [0x68589adc7687A23Ff2B06fb032b997f09B44Ed5d](https://optimistic.etherscan.io/address/0x68589adc7687A23Ff2B06fb032b997f09B44Ed5d)
- Base: [0x68589adc7687A23Ff2B06fb032b997f09B44Ed5d](https://basescan.org/address/0x68589adc7687A23Ff2B06fb032b997f09B44Ed5d)
- Taiko: [0x68589adc7687A23Ff2B06fb032b997f09B44Ed5d](https://taikoscan.io/address/0x68589adc7687A23Ff2B06fb032b997f09B44Ed5d)
- Hemi: [0x68589adc7687A23Ff2B06fb032b997f09B44Ed5d](https://explorer.hemi.xyz/address/0x68589adc7687A23Ff2B06fb032b997f09B44Ed5d)

## Project Overview

This repository includes:

- **Smart Contracts**: Contracts for Yieldnest's cross-chain tokens.
- **Deployment Scripts**: Scripts for deploying and configuring the contracts across multiple chains.
- **Testing Framework**: Tests using Foundry's Forge tool.

### Key Contracts and Scripts

- **Main Contracts**:

  - `L2YnERC20Upgradeable.sol`: Layer 2 upgradeable ERC20 token contract.
  - `ImmutableMultiChainDeployer.sol`: Handles multi-chain deployment of contracts.
  - `L1YnOFTAdapterUpgradeable.sol`: Adapter for Layer 1 OFT (Omnichain Fungible Token).
  - `L2YnOFTAdapterUpgradeable.sol`: Adapter for Layer 2 OFT.

- **Deployment Scripts**:
  - `deploy.sh`: The main deployment script that handles deployments across multiple chains.
  - `DeployL2OFTAdapter.s.sol`: Deploys the Layer 2 ERC20 token and OFT Adapter.
  - `DeployL1OFTAdapter.s.sol`: Deploys the Layer 1 OFT Adapter.
  - `VerifyL2OFTAdapter.s.sol`: Verifys the Layer 2 ERC20 token and OFT Adapter.
  - `VerifyL1OFTAdapter.s.sol`: Verifys the Layer 1 OFT Adapter.

## Prerequisites

- **Foundry**: A fast, portable, and modular toolkit for Ethereum development.
- **Yarn**: Dependency management tool used in this project.
- **Solidity**: For developing smart contracts.

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/yieldnest/yieldnest-cross-chain.git
cd yieldnest-cross-chain
```

### 2. Install Dependencies

This project uses `yarn` to manage dependencies

```bash
yarn install
```

## Usage

### Build

To build the project, use the following command. This will compile all Solidity contracts:

```bash
yarn build
```

### Compile

You can compile contracts using Foundry's `forge`:

```bash
forge compile
```

### Test

Run the tests with the following command:

```bash
yarn test
```

### Lint

To lint Solidity files using `solhint`, run:

```bash
yarn lint
```

This will check all Solidity files in the `src/`, `test/`, and `scripts/` directories for issues, adhering to the project's `solhint` configuration.

### Format

You can format your Solidity code using:

```bash
yarn format
```

### Scripts

For most users, it is recommended to use the `yarn deploy` command (outlined in the following section), as it simplifies the deployment process and ensures all necessary configurations are handled across multiple chains. Running the Forge scripts manually should only be done if you have a deep understanding of the deployment steps.

However, if you need to run a script manually (e.g., `DeployL1OFTAdapter`), you can use the following command pattern:

```bash
forge script DeployOFT --rpc-url ${rpc} \
--sig "run(string calldata)" ${path} \
--account ${deployerAccountName} --sender ${deployer} \
--broadcast --etherscan-api-key ${api} --verify
```

Replace `DeployOFT` with the relevant contract name for other scripts if needed. But again, for ease and accuracy, the `yarn deploy` command is recommended.

All scripts must be run for every L1 and L2 chain you're deploying to if you wish to deploy manually. The Bash script will handle this automatically.

When contracts are deployed often ownership of the contracts will not be transferred in order to assure correct OFT settings without having to do transactions through governance. See the Transfer Ownership section below for details.

### Deployment

To deploy Yieldnest tokens to new chains, you can use the `yarn deploy` command, which runs the `script/deploy.sh` script. This script accepts an input JSON file that specifies the token and chain configurations for deployment.

For example, to deploy the `ynETH` token to the specified networks, use the following command:

```bash
yarn deploy script/inputs/mainnet-ynETH.json
```

You can find template JSON files for reference in the `script/inputs/` directory. Below is an example of a typical input file:

```json
{
  "erc20Name": "ynETH MAX",
  "erc20Symbol": "ynETHx",
  "erc20Decimals": 18,
  "l1ChainId": 1,
  "l2ChainIds": [5000, 81457],
  "l1ERC20Address": "0x657d9ABA1DBb59e53f9F3eCAA878447dCfC96dCb",
  "rateLimitConfig": {
    "limit": "3000000000000000000000",
    "window": "3600"
  }
}
```

This script will deploy all the necessary contracts across the chains specified in the JSON file, including both the Layer 1 and all Layer 2 chains.

### Adding a New L2 Chain

This repo is uses Layer Zero V2 so please use all applicable V2 libraries when adding addresses.
All Layer zero deployed endpoints, message libraries, and executors for supported chains can be found in the layer zero [docs](https://docs.layerzero.network/v2/deployments/deployed-contracts)
DVNs can be found [here](https://docs.layerzero.network/v2/deployments/dvn-addresses)

To add a new L2 chain to an existing deployment, follow these steps using Morph Testnet (which is not supported by layer zero) as an example:

1. Update the `BaseData.s.sol` file:

   - Add the new testnet chain's ID to the `ChainIds` struct:
     ```solidity
     struct ChainIds {
         // ... existing chain IDs
         uint256 morphTestnet;
     }
     ```
   - Initialize the new testnet chain ID in the `__chainIds` variable:
     ```solidity
     __chainIds = ChainIds({
         // ... existing chain IDs
         morphTestnet: 2810
     });
     ```
   - Add the testnet chain-specific data to the `setUp()` function:
     ```solidity
     __chainIdToData[__chainIds.morphTestnet] = Data({
         OFT_OWNER: TEMP_GNOSIS_SAFE,
         TOKEN_ADMIN: TEMP_GNOSIS_SAFE,
         PROXY_ADMIN: TEMP_PROXY_CONTROLLER,
         LZ_ENDPOINT: 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B,
         LZ_SEND_LIB: 0xC39161c743D0307EB9BCc9FEF03eeb9Dc4802de7,
         LZ_RECEIVE_LIB: 0xe1844c5D63a9543023008D332Bd3d2e6f1FE1043,
         LZ_DVN: 0xf10ea2c0d43bc4973cfbcc94ebafc39d1d4af118,
         NETHERMIND_DVN: 0xdf30c9f6a70ce65a152c5bd09826525d7e97ba49,
         LZ_EXECUTOR: 0xcCE466a522984415bC91338c232d98869193D46e,
         LZ_EID: 30210 // LayerZero Endpoint ID for Morph Testnet
     });
     ```

2. Update the deployment input JSON file for testnets (e.g., `script/inputs/holesky-ynETH.json`):

   - Add the new testnet chain ID to the `l2ChainIds` array:
     ```json
     {
       "l2ChainIds": [2522, 2810]
       // ... other existing configuration
     }
     ```

3. Add the new testnet chain's RPC URL to the `.env` file:

   ```
   MORPH_TESTNET_RPC_URL=https://rpc-testnet.morphl2.io
   ```

4. Update the `foundry.toml` file to include the new testnet RPC endpoint:

   ```toml
   [rpc_endpoints]
   morph_testnet = "${MORPH_TESTNET_RPC_URL}"
   ```

5. Run the deployment script for the testnet environment:

   ```bash
   yarn deploy script/inputs/holesky-ynETH.json
   ```

   This will deploy the necessary contracts on the new Morph Testnet chain and update the existing contracts on other testnet chains to recognize the new L2 testnet.

6. After deployment, verify that the new testnet chain has been properly added:

   - Check that the L2YnOFTAdapter on Morph Testnet has the correct peers set for all other testnet chains.
   - Verify that all other L2YnOFTAdapters and the L1YnOFTAdapter on testnets have been updated to include Morph Testnet as a peer.

7. Update any front-end applications or scripts to include support for the new Morph Testnet chain, such as adding it to the list of supported testnet networks and including its contract addresses.

By following these steps, you can successfully add Morph Testnet (or any other new L2 testnet chain) to your existing multi-chain testnet deployment.

### Possible Multisig transactions

If adding a chain to an existing deployment, you will more than likely need to execute a multisig transaction to set the DVN and executor for the OFT Adapter on the existing l1 chain.  The Deploy script will automatically read the existing oft settings and output an encoded multisig batch transaction which will need to be executed on the L1 chain, *if ownership has been transferred to the multisig*.  the transactions will be output into the console and will need to be copied from there.


### Transfer Ownership

Running the TransferOFTOwnership script will transfer ownership of the oft from the deployer address to the OFT_OWNER address in BaseData.s.sol

```
        __chainIdToData[__chainIds.mainnet] = Data({
            OFT_OWNER: 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975, // <=== This variable for that chain
        })
```

For transferring contract ownership run:

```bash
// forge script TransferOFTOwnership --rpc-url ${rpc} \
// --sig "run(string calldata,string calldata)" ${input_path} ${deployment_path} \
// --account ${deployerAccountName} --sender ${deployer} --broadcast
```

on all relevant chains.

### Gas Snapshots

To generate gas usage reports for the contracts, run:

```bash
forge snapshot
```

## Project Structure

- `src/`: Contains the core smart contracts for the project.
- `script/`: Contains deployment scripts for the contracts.
- `test/`: Contains tests for the contracts, utilizing Forge.
- `deployments/`: Contains deployment artifacts and configuration files for different environments.
- `foundry.toml`: Foundry configuration file.
- `package.json`: Yarn configuration file for managing dependencies.
- `remappings.txt`: Foundry remappings for import resolution.

## Linting

This project uses `husky` for Git hooks and `forge fmt` for Solidity file formatting. Pre-commit hooks are set up using `lint-staged` to automatically format `.sol` files on commit.

In addition, `solhint` is used to lint Solidity files. You can run `yarn lint` to manually check the code for common issues and enforce style guidelines.

## Documentation

For more information on Foundry and how to use it, please refer to the [Foundry Book](https://book.getfoundry.sh/).

## License

This project is licensed under the MIT License.
