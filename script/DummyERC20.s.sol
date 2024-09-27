//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {DummyERC20} from "src/DummyERC20.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DummyERC20Script is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        DummyERC20 erc20 = new DummyERC20("TEST", "TEST");
        console2.log("implementation address: ", address(erc20));
        vm.stopBroadcast();
    }
}
