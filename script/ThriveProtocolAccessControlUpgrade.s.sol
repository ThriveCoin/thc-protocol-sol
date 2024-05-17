// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";

contract ThriveProtocolAccessControlUpgradeScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxy = vm.envAddress("ACCESS_CONTROL_PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        ThriveProtocolAccessControl newImplementation =
            new ThriveProtocolAccessControl();
        ThriveProtocolAccessControl proxyContract =
            ThriveProtocolAccessControl(payable(proxy));
        proxyContract.upgradeToAndCall(address(newImplementation), "");
        vm.stopBroadcast();

        console2.log("new implementation address: ", address(newImplementation));
    }
}
