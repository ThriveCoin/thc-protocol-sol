// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {ThriveProtocolContributors} from "src/ThriveProtocolContributors.sol";

contract ThriveProtocolContributorsUpgradeScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxy = vm.envAddress("CONTRIBUTORS_PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        ThriveProtocolContributors newImplementation =
            new ThriveProtocolContributors();
        ThriveProtocolContributors proxyContract =
            ThriveProtocolContributors(payable(proxy));
        proxyContract.upgradeToAndCall(address(newImplementation), "");
        vm.stopBroadcast();

        console2.log("new implementation address: ", address(newImplementation));
    }
}
