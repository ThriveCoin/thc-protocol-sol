# THC Protocol (Solidity)

This project includes the smart contracts related to Thrive Protocol.

## Table of Contents

- [Setup](#setup)
- [Testing](#testing)
- [Build](#build)
- [Deployment](#deployment)
- [Updating Contracts](#updating-contracts)
- [Initializing Submodules](#initializing-submodules)
- [Check balance](#check-balance)
- [Notes](#notes)

## Setup

To set up the project, follow these steps:

1. **Clone the repository:**

2. **Install dependencies:**

   Ensure you have [Foundry](https://github.com/gakonst/foundry) installed. If not, install it by running:

   ```sh
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

   Then install project dependencies:

   ```sh
   forge install
   ```

3. **Set up environment variables:**

   Create a `.env` file in the root directory of the project and add all variables from `.env.example` adding the actual values.

4. **Generate remappings:**

   Run the following command to generate remappings for your dependencies:

   ```sh
   forge remappings > remappings.txt
   ```

## Testing

To run the tests for the smart contracts, use the following command:

```sh
forge test
```

### Build

Make sure you have built the latest version of the contracts before a deployment

```sh
forge build
```

## Deployment

Before deploying, ensure you have your environment variables set up. You can source your environment configuration from a file:

```sh
source .env
```

### Deploying Contracts

```sh
forge script [--legacy] <path>/<name.s.sol> --chain <chain name> --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $SCAN_API_KEY
```

Deploy the `ThriveProtocolAccessControl` with specific arguments:

```sh
forge script --legacy script/ThriveProtocolAccessControl.s.sol --chain sepolia --rpc-url $RPC_URL --private-key $PRIVATE_KEY -vvvv --broadcast --verify --etherscan-api-key $SCAN_API_KEY
```

### Updating Contracts

Before upgrading contracts, ensure your environment variables are set also as $PROXY_ADDRESS, then run the following commands for a contract upgrade:

```sh
forge script <path>/<name.s.sol> --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

Upgrade the `ThriveProtocolAccessControl` with specific arguments:

```sh
forge script script/ThriveProtocolAccessControlUpgrade.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY -vvvv --broadcast
```

You can follow a similar process for other contract upgrades.

### Verifying Contracts

Source code can be taken from both script files and source files

```sh
forge verify-contract --chain <chain name> --etherscan-api-key $SCAN_API_KEY --watch <look for chain in `foundry.toml`> <address> <path>:<contractname>
```

Example 1 (source code):

```sh
forge verify-contract --chain sepolia --etherscan-api-key $SCAN_API_KEY --watch 0xDC448EA9951e2A6038260784Cc96A0adb81Cc4f8 src/ThriveProtocolAccessControl.sol:ThriveProtocolAccessControl
```

Example 2 (libs):

```sh
forge verify-contract --chain sepolia --etherscan-api-key $SCAN_API_KEY --watch --constructor-args $(cast abi-encode "constructor(address,bytes)" "0xDC448EA9951e2A6038260784Cc96A0adb81Cc4f8" "0x") 0x6508Dc35baF1dd6b07874Ff6174E1e8E989E8300 lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
```

## Initializing Submodules

If your project includes submodules, initialize them with the following command:

```sh
git submodule update --init --recursive
```

## Check balance

Show address balance in ETH

```sh
cast balance <address>  --rpc-url $RPC_URL -e
```

## Notes

- Ensure you have the necessary environment variables set in your `.env` or `.env.development` file.
- The `-vvvv` flag in the `forge` commands is for verbose output, which can be helpful for debugging.
- The `--broadcast` flag executes the deployment on the specified network.
- The `--verify` flag automatically verifies the contract on Etherscan using the provided API key.
