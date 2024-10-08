// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {ThriveProtocolIERC20Reward} from "src/ThriveProtocolIERC20Reward.sol";

contract ThriveProtocolIERC20RewardUpgradeScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxy = vm.envAddress("REWARD_PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        ThriveProtocolIERC20Reward newImplementation =
            new ThriveProtocolIERC20Reward();
        ThriveProtocolIERC20Reward proxyContract =
            ThriveProtocolIERC20Reward(payable(proxy));
        proxyContract.upgradeToAndCall(address(newImplementation), "");
        vm.stopBroadcast();

        console2.log("new implementation address: ", address(newImplementation));
    }
}
