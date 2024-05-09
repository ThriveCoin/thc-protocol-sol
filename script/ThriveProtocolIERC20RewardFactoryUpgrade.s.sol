// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {ThriveProtocolIERC20RewardFactory} from "src/ThriveProtocolIERC20RewardFactory.sol";

contract ThriveProtocolCommunityFactoryUpgradeScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxy = vm.envAddress("COMMUNITY_FACTORY_PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        ThriveProtocolIERC20RewardFactory newImplementation =
            new ThriveProtocolIERC20RewardFactory();
        ThriveProtocolIERC20RewardFactory proxyContract =
            ThriveProtocolIERC20RewardFactory(payable(proxy));
        proxyContract.upgradeToAndCall(address(newImplementation), "");
        vm.stopBroadcast();

        console2.log("new implementation address: ", address(newImplementation));
    }
}