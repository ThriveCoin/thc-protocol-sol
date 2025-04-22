// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ThriveProtocolBadgeQuery} from "src/ThriveProtocolBadgeQuery.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployThriveProtocolBadgeQuery is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address accessControl = vm.envAddress("ACCESS_CONTROL_ADDRESS");
        bytes32 role = vm.envBytes32("BADGE_ADMIN_ROLE");

        vm.startBroadcast(deployerPrivateKey);

        ThriveProtocolBadgeQuery implementation = new ThriveProtocolBadgeQuery();
        console2.log("BadgeQuery Logic deployed at:", address(implementation));

        bytes memory initData = abi.encodeWithSelector(
            ThriveProtocolBadgeQuery.initialize.selector, accessControl, role
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console2.log("BadgeQuery Proxy deployed at:", address(proxy));

        vm.stopBroadcast();
    }
}
