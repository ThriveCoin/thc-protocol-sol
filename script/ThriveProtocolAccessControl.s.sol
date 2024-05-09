//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ThriveProtocolAccessControlScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        ThriveProtocolAccessControl implementation =
            new ThriveProtocolAccessControl();
        console2.log("implementation address: ", address(implementation));

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        implementation = ThriveProtocolAccessControl(address(proxy));
        implementation.initialize();
        vm.stopBroadcast();
        console2.log("proxy address: ", address(proxy));
    }
}
