//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ThriveProtocolContributors} from "src/ThriveProtocolContributors.sol";

contract ThriveProtocolContributorsScript is Script {
    function run(address contributions) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        ThriveProtocolContributors contributors =
            new ThriveProtocolContributors(contributions);
        vm.stopBroadcast();
        console2.log("contributors address: ", address(contributors));
    }
}
