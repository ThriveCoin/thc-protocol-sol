//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ThriveProtocolContributions} from "src/ThriveProtocolContributions.sol";

contract ThriveProtocolContributionsScript is Script {
    function run(address accessControlEnumerable, bytes32 role) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        ThriveProtocolContributions contributions =
            new ThriveProtocolContributions(accessControlEnumerable, role);
        vm.stopBroadcast();
        console2.log("contributions address: ", address(contributions));
    }
}
