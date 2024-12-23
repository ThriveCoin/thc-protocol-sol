// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {ThriveBridgeDestination} from "src/ThriveBridgeDestination.sol";

import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ThriveBridgeDestinationScript is Script {
    function setUp() public {}

    function run(
        address srcContract,
        address accessControl,
        bytes32 role,
        address token
    ) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ThriveBridgeDestination implementation = new ThriveBridgeDestination();
        console2.log("implementation address: ", address(implementation));

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");

        implementation = ThriveBridgeDestination(address(proxy));
        implementation.initialize(srcContract, accessControl, role, token);
        vm.stopBroadcast();

        console2.log("proxy address: ", address(proxy));
    }
}
