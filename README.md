# Yieldnest Cross-Chain Contracts

This project contains the smart contracts and scripts for deploying cross-chain Yieldnest tokens using LayerZero technology. It leverages the Foundry development toolkit for testing, building, and deploying contracts, and uses Yarn to manage dependencies.

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
  - `DeployMultiChainDeployer.s.sol`: Deploys the `ImmutableMultiChainDeployer`.
  - `DeployL2OFTAdapter.s.sol`: Deploys the Layer 2 ERC20 token and OFT Adapter.
  - `DeployL1OFTAdapter.s.sol`: Deploys the Layer 1 OFT Adapter.
  - `SetPeersOFTAdapter.s.sol`: Configures peer relationships between the OFT adapters.

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
forge test -vvv
```

The `-vvv` flag provides verbose output for more detailed test results.

### Format

You can format your Solidity code using:

```bash
forge fmt
```

### Deploy

To deploy one of the main scripts (e.g., `DeployMultiChainDeployer`), use the following pattern:

```bash
forge script script/DeployMultiChainDeployer.s.sol:DeployMultiChainDeployer \
  --rpc-url ${rpc} --sig "run(string calldata)" ${path} \
  --account ${deployerAccountName} --sender ${deployer} \
  --broadcast --etherscan-api-key ${api} --verify
```

Replace `DeployMultiChainDeployer` with the desired contract name for other scripts.

### Gas Snapshots

To generate gas usage reports for the contracts, run:

```bash
forge snapshot
```

### Anvil

You can use Anvil, the local Ethereum testnet, with:

```bash
anvil
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

## Documentation

For more information on Foundry and how to use it, please refer to the [Foundry Book](https://book.getfoundry.sh/).

## License

This project is licensed under the MIT License.
