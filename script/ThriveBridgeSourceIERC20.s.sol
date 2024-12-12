// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {ThriveBridgeSourceIERC20} from "src/ThriveBridgeSourceIERC20.sol";

import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ThriveBridgeSourceIERC20Script is Script {
    function setUp() public {}

    function run(
        address destContract,
        address accessControl,
        bytes32 role,
        address token
    ) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ThriveBridgeSourceIERC20 implementation = new ThriveBridgeSourceIERC20();
        console2.log("implementation address: ", address(implementation));

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");

        implementation = ThriveBridgeSourceIERC20(address(proxy));
        implementation.initialize(destContract, accessControl, role, token);
        vm.stopBroadcast();

        console2.log("proxy address: ", address(proxy));
    }
}
