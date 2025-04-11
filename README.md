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
  - `L1YnOFTAdapterUpgradeable.sol`: Adapter for Layer 1 OFT (Omnichain Fungible Token).
  - `L2YnOFTAdapterUpgradeable.sol`: Adapter for Layer 2 OFT.

- **Deployment Scripts**:
  - `script/deploy/1_DeployOFT.s.sol`: Deploys the OFT Adapter.
  - `script/deploy/2_ConfigureOFT.s.sol`: Configures the OFT Adapter.
  - `script/deploy/3_TransferOFTOwnership.s.sol`: Transfers the ownership of the OFT Adapter to the admin.
  - `script/deploy/4_VerifyOFT.s.sol`: Verifies the OFT Adapter.

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

### Deployment

To deploy Yieldnest tokens to new chains, follow the sequence of commands below. Each step is idempotent and can be safely re-run.

1. **Deploy**

```bash
yarn deploy script/inputs/mainnet-ynETH.json
```

This step deploys the OFT adapters (and ERC20 contracts for L2 chains). If already deployed for a chain, it will skip deployment for that chain.

2. **Configure**

```bash
yarn configure script/inputs/mainnet-ynETH.json deployments/ynETH-1-v0.0.1.json
```

This step configures the deployed OFT contracts. It will only apply necessary changes.

3. **Transfer Ownership**

```bash
yarn transfer-ownership script/inputs/mainnet-ynETH.json deployments/ynETH-1-v0.0.1.json
```

Transfers ownership of the OFT contracts from the deployer to the admin address.

4. **Verify**

```bash
yarn verify script/inputs/mainnet-ynETH.json deployments/ynETH-1-v0.0.1.json
```

Verifies the full OFT setup. This will output any differences or issues found.

### Adding a New L2 Chain

To add a new L2 chain to an existing deployment, follow these steps using Morph Testnet as an example:

1. **Add support for the new chain**:
   - a) Update the `foundry.toml` file to include the RPC endpoint:
     ```toml
     [rpc_endpoints]
     // ... existing networks
     morph_testnet = "${MORPH_TESTNET_RPC_URL}"
     ```

   - b) Update `script/BaseData.s.sol`:
     - Add the new chain ID to the `ChainIds` struct:
       ```solidity
       struct ChainIds {
           // ... existing chain IDs
           uint256 morphTestnet;
       }
       ```
     - Initialize it in the `__chainIds` assignment:
       ```solidity
       __chainIds = ChainIds({
           // ... existing
           morphTestnet: 2810
       });
       ```
     - Add to `setUp()`:
       ```solidity
       __chainIdToData[__chainIds.morphTestnet] = Data({
           OFT_OWNER: TEMP_GNOSIS_SAFE,
           TOKEN_ADMIN: TEMP_GNOSIS_SAFE,
           PROXY_ADMIN: TEMP_PROXY_CONTROLLER,
           LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
           LZ_EID: 30210,
           // .. add other config
       });
       ```

   - c) Update `script/BatchScript.s.sol`:
     ```solidity
     } else if (chainId == 2810) {
         SAFE_API_BASE_URL = "";
         SAFE_MULTISEND_ADDRESS = 0x998739BFdAAdde7C933B942a68053933098f9EDa;
     }
     ```

   - d) Update `script/bash/network_config.sh` and add support for the new chain.

2. **Update the deployment input JSON file** (e.g., `script/inputs/holesky-ynETH.json`):
   - Add the new testnet chain ID to the `l2ChainIds` array:
     ```json
     {
       "l2ChainIds": [
         2522,
         2810
       ],
       // ... other config
     }
     ```

3. **Add the testnet RPC URL to the `.env` file**:
   ```
   MORPH_TESTNET_RPC_URL=https://rpc-testnet.morphl2.io
   ```

4. **Run the deployment script**:
   ```bash
   yarn deploy script/inputs/holesky-ynETH.json
   ```
   This step deploys the necessary contracts on the new Morph Testnet chain.

5. **Run the configuration script**:
   ```bash
   yarn configure script/inputs/holesky-ynETH.json deployments/ynETH-17000-v0.0.1.json
   ```
   Configures the OFT contracts on all chains listed in the input file.

6. **Transfer ownership**:
   ```bash
   yarn transfer-ownership script/inputs/holesky-ynETH.json deployments/ynETH-17000-v0.0.1.json
   ```

7. **Verify the setup**:
   ```bash
   yarn verify script/inputs/holesky-ynETH.json deployments/ynETH-17000-v0.0.1.json
   ```
   The verification script will console log any manual configurations that still need to be set. Be sure to execute those steps manually.

8. **Test bridging to/from the new chain**:  
   Run `script/commands/BridgeAsset.s.sol` to test bridging the asset to and from the new chain. This ensures the deployment and configuration are working correctly end-to-end.

By following these steps, you can successfully add Morph Testnet (or any other new L2 testnet chain) to your existing multi-chain testnet deployment.

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
