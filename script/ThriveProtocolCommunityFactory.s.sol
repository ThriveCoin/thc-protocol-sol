//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ThriveProtocolCommunityFactory} from
    "src/ThriveProtocolCommunityFactory.sol";

contract ThriveProtocolCommunityFactoryScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        ThriveProtocolCommunityFactory factory =
            new ThriveProtocolCommunityFactory();
        vm.stopBroadcast();
        console2.log("factory address: ", address(factory));
    }
}
