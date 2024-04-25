# thc-protocol-sol

This project includes the smart contracts related to Thrive Protocol.

## Testing

```
forge test
```

## Deploy

```
source .env (or .env.development)
```

```
forge script --sig "run(address,bytes32,address)" --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY -vvvv --broadcast --verify --etherscan-api-key $API_KEY ThriveProtocolIERC20RewardScript  <access_control_address> <admin_role> <token_address>
```

```
forge script --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY -vvvv --broadcast --verify --etherscan-api-key $API_KEY ThriveProtocolCommunityFactoryScript
```

```
forge create --constructor-args <owner_address> <community_name> <admins_address> <rewards> <access_control_address> <admin_role>  --rpc-url $SEPOLIA_RPC_URL  --private-key $PRIVATE_KEY --etherscan-api-key $API_KEY --verify ThriveProtocolCommunity
```

```
forge script --sig "run(address,bytes32)" --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY -vvvv --broadcast --verify --etherscan-api-key $API_KEY ThriveProtocolContributorsScript  <access_control_address> <admin_role>
```

```
forge script --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY -vvvv --broadcast --verify --etherscan-api-key $API_KEY ThriveProtocolContributionsScript
```

## Update

```
source .env (or .env.development)
```

```
forge script --legacy --rpc-url $RPC_URL -vvvv --broadcast script/ThriveProtocolIERC20RewardUpgrade.s.sol

# similar for other contracts
```

## Init submodules

```
git submodule update --init --recursive
```
