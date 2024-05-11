//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveProtocolCommunity} from "src/ThriveProtocolCommunity.sol";
import "test/mock/MockAccessControl.sol";
import "src/ThriveProtocolCommunityFactory.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract ThriveProtocolCommunityFactoryTest is Test {
    bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");

    ThriveProtocolCommunityFactory factory;
    MockAccessControl accessControl;

    address rewardsAdmin;
    address treasuryAdmin;
    address validationsAdmin;
    address foundationAdmin;

    function setUp() public {
        rewardsAdmin = address(2);
        treasuryAdmin = address(3);
        validationsAdmin = address(4);
        foundationAdmin = address(5);

        vm.startPrank(address(6));
        accessControl = new MockAccessControl();
        vm.stopPrank();

        vm.prank(address(1));
        factory = new ThriveProtocolCommunityFactory();
        factory.initialize();
    }

    ////////////
    // deploy //
    ////////////

    function test_deploy() public {
        vm.startPrank(address(1));
        (address communityImpl, address communityProxy) = factory.deploy(
            "test",
            [rewardsAdmin, treasuryAdmin, validationsAdmin, foundationAdmin],
            [uint256(80), 5, 5, 10],
            address(accessControl),
            ADMIN_ROLE
        );

        assertEq(ThriveProtocolCommunity(communityProxy).name(), "test");
    }
}
