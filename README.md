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
forge script script/DeployL1OFTAdapter.s.sol:DeployL1OFTAdapter \
  --rpc-url ${rpc} --sig "run(string calldata)" ${path} \
  --account ${deployerAccountName} --sender ${deployer} \
  --broadcast --etherscan-api-key ${api} --verify
```

Replace `DeployL1OFTAdapter` with the relevant contract name for other scripts if needed. But again, for ease and accuracy, the `yarn deploy` command is recommended.

### Deployment

To deploy Yieldnest tokens to new chains, you can use the `yarn deploy` command, which runs the `script/deploy.sh` script. This script accepts an input JSON file that specifies the token and chain configurations for deployment.

For example, to deploy the `ynETH` token to the specified networks, use the following command:

```bash
yarn deploy script/inputs/mainnet-ynETH.json
```

You can find template JSON files for reference in the `script/inputs/` directory. Below is an example of a typical input file:

```json
{
  "erc20Name": "ynETH",
  "erc20Symbol": "ynETH",
  "l1ChainId": 1,
  "l2ChainIds": [
    10,
    8453
  ],
  "l1ERC20Address": "0x09db87A538BD693E9d08544577d5cCfAA6373A48",
  "rateLimitConfig": {
    "limit": "100000000000000000000",
    "window": "86400"
  }
}
```

This script will deploy all the necessary contracts across the chains specified in the JSON file, including both the Layer 1 and all Layer 2 chains.

#### Adding New Chains

If you need to add a new chain after an initial deployment, you can update the input JSON file by adding the new chain's ID to the `l2ChainIds` list and re-run the deployment command:

```bash
yarn deploy script/inputs/mainnet-ynETH.json
```

This will deploy the required contracts on the new chain and provide instructions if any manual configuration is needed on previously deployed networks to support the new chain.

The deployment script also includes a verification step to ensure that the contracts have been deployed and configured correctly across all chains.

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
