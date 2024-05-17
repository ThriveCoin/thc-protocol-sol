//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ThriveProtocolIERC20RewardFactory} from
    "src/ThriveProtocolIERC20RewardFactory.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ThriveProtocolCommunityFactoryScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        ThriveProtocolIERC20RewardFactory implementation =
            new ThriveProtocolIERC20RewardFactory();
        console2.log("implementation address: ", address(implementation));

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        implementation = ThriveProtocolIERC20RewardFactory(address(proxy));
        implementation.initialize();
        vm.stopBroadcast();
        console2.log("proxy address: ", address(proxy));
    }
}