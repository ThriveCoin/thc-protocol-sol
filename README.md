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
forge script --legacy --sig "run(address,bytes32,address)" --rpc-url $RPC_URL -vvvv --broadcast --verify --etherscan-api-key $API_KEY ./script/ThriveProtocolERC20Reward.s.sol -- <access-control-enum> <role> <erc20>

# similar for other contracts
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
