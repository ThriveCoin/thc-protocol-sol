//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ThriveProtocolContributions} from "src/ThriveProtocolContributions.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ThriveProtocolContributionsScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        ThriveProtocolContributions implementation =
            new ThriveProtocolContributions();
        console2.log("implementation address: ", address(implementation));

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        implementation = ThriveProtocolContributions(address(proxy));
        implementation.initialize();
        vm.stopBroadcast();
        console2.log("proxy address: ", address(proxy));
    }
}
