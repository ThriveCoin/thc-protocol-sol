//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ThriveIERC20Wrapper} from "src/ThriveIERC20Wrapper.sol";

contract ThriveIERC20WrapperScript is Script {
    function setUp() public {}

    function run(string memory name, string memory symbol, uint8 decimals)
        external
    {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        ThriveIERC20Wrapper erc20 =
            new ThriveIERC20Wrapper(name, symbol, decimals);
        console2.log("implementation address: ", address(erc20));
        vm.stopBroadcast();
    }
}
