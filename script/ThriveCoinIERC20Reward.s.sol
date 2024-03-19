// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {ThriveProtocolIERC20Reward} from "src/ThriveProtocolIERC20Reward.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ThriveProtocolIERC20RewardScript is Script {
    function setUp() public {}

    function run(address token) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address accessControll = vm.envAddress("ACCESS_CONTROL_CONTRACT");

        vm.startBroadcast(deployerPrivateKey);

        ThriveProtocolIERC20Reward implementation = new ThriveProtocolIERC20Reward();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");

        implementation = ThriveProtocolIERC20Reward(address(proxy));
        implementation.initialize(accessControll, token);
        vm.stopBroadcast();

        console2.log("address: ", address(implementation));
    }
}
