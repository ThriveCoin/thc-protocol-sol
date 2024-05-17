// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {ThriveProtocolCommunityFactory} from
    "src/ThriveProtocolCommunityFactory.sol";

contract ThriveProtocolCommunityFactoryUpgradeScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxy = vm.envAddress("COMMUNITY_FACTORY_PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        ThriveProtocolCommunityFactory newImplementation =
            new ThriveProtocolCommunityFactory();
        ThriveProtocolCommunityFactory proxyContract =
            ThriveProtocolCommunityFactory(payable(proxy));
        proxyContract.upgradeToAndCall(address(newImplementation), "");
        vm.stopBroadcast();

        console2.log("new implementation address: ", address(newImplementation));
    }
}
