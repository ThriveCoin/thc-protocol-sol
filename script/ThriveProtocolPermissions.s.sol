//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ThriveProtocolPermissions} from "src/ThriveProtocolPermissions.sol";

contract ThriveProtocolPermissionsScript is Script {
    function run(address accessControl, bytes32 role, address rootAdmin) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        ThriveProtocolPermissions permissions =
            new ThriveProtocolPermissions(accessControl, role, rootAdmin);
        vm.stopBroadcast();
        console2.log("permissions address: ", address(permissions));
    }
}