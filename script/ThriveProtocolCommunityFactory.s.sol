//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ThriveProtocolCommunityFactory} from "src/ThriveProtocolCommunityFactory.sol";

contract ThriveProtocolCommunityFactoryScript is Script {
    function run(
        address _rewardsAdmin,
        address _treasuryAdmin,
        address _validationsAdmin,
        address _foundationAdmin,
        uint256 _rewardsPercent,
        uint256 _treasuryPercent,
        uint256 _validationsPercent,
        uint256 _foundationPercent,
        address _accessControlEnumerable
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        ThriveProtocolCommunityFactory factory = new ThriveProtocolCommunityFactory(
                _rewardsAdmin,
                _treasuryAdmin,
                _validationsAdmin,
                _foundationAdmin,
                _rewardsPercent,
                _treasuryPercent,
                _validationsPercent,
                _foundationPercent,
                _accessControlEnumerable
            );
        vm.stopBroadcast();
        console2.log("factory address: ", address(factory));
    }
}
