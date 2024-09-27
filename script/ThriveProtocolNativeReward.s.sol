// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {ThriveProtocolNativeReward} from "src/ThriveProtocolNativeReward.sol";

import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ThriveProtocolNativeRewardScript is Script {
    function setUp() public {}

    function run(address accessControl, bytes32 role) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ThriveProtocolNativeReward implementation =
            new ThriveProtocolNativeReward();
        console2.log("implementation address: ", address(implementation));

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");

        implementation = ThriveProtocolNativeReward(payable(address(proxy)));
        implementation.initialize(accessControl, role);
        vm.stopBroadcast();

        console2.log("proxy address: ", address(proxy));
    }
}
