// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {ThriveProtocolIERC20Reward} from "src/ThriveProtocolIERC20Reward.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ThriveProtocolIERC20RewardScript is Script {
    function setUp() public {}

    function run(address accessControl, address token) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        console2.log(msg.sender);

        ThriveProtocolIERC20Reward implementation = new ThriveProtocolIERC20Reward();
        console2.log("implementation address: ", address(implementation));

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");

        implementation = ThriveProtocolIERC20Reward(address(proxy));
        console2.log(msg.sender);
        implementation.initialize(accessControl, token);
        vm.stopBroadcast();

        console2.log("proxy address: ", address(proxy));
    }
}
