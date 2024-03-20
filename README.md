## Deploy

```
source .env (or .env.development)
```

```
forge script --sig "run(address,address)" --rpc-url $RPC_URL -vvvv --broadcast --verify --etherscan-api-key $API_KEY script/ThriveProtocolIERC20Reward.s.sol <access_control_address> <token_address>
```

## Update

```
source .env (or .env.development)
```

```
forge script --rpc-url $RPC_URL -vvvv --broadcast script/ThriveProtocolIERC20RewardUpgrade.s.sol
```
