// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {ThriveProtocolContributions} from "src/ThriveProtocolContributions.sol";

contract ThriveProtocolContributionsUpgradeScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxy = vm.envAddress("CONTRIBUTIONS_PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        ThriveProtocolContributions newImplementation =
            new ThriveProtocolContributions();
        ThriveProtocolContributions proxyContract =
            ThriveProtocolContributions(payable(proxy));
        proxyContract.upgradeToAndCall(address(newImplementation), "");
        vm.stopBroadcast();

        console2.log("new implementation address: ", address(newImplementation));
    }
}