//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ThriveProtocolContributors} from "src/ThriveProtocolContributors.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ThriveProtocolContributorsScript is Script {
    function run(address contributions) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        ThriveProtocolContributors implementation =
            new ThriveProtocolContributors();
        console2.log("implementation address: ", address(implementation));

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        implementation = ThriveProtocolContributors(address(proxy));
        implementation.initialize(contributions);
        vm.stopBroadcast();
        console2.log("proxy address: ", address(proxy));
    }
}
