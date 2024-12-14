// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {ThriveBridgeSourceNative} from "src/ThriveBridgeSourceNative.sol";

import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ThriveBridgeSourceNativeScript is Script {
    function setUp() public {}

    function run(address destContract, address accessControl, bytes32 role)
        public
    {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ThriveBridgeSourceNative srcImplementation =
            new ThriveBridgeSourceNative();
        console2.log("implementation address: ", address(srcImplementation));

        ERC1967Proxy srcProxy = new ERC1967Proxy(address(srcImplementation), "");

        srcImplementation = ThriveBridgeSourceNative(address(srcProxy));
        srcImplementation.initialize(destContract, accessControl, role);
        vm.stopBroadcast();

        console2.log("proxy address: ", address(srcProxy));
    }
}
