//SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveProtocolCommunity} from "src/ThriveProtocolCommunity.sol";
import "test/mock/MockAccessControl.sol";
import "src/ThriveProtocolCommunityFactory.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract ThriveProtocolCommunityFactoryTest is Test {
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
        accessControl.grantRole(0x00, address(1));
        vm.stopPrank();

        vm.prank(address(1));
        factory = new ThriveProtocolCommunityFactory(
            rewardsAdmin,
            treasuryAdmin,
            validationsAdmin,
            foundationAdmin,
            80,
            5,
            5,
            10,
            address(accessControl)
        );
    }

    ////////////
    // deploy //
    ////////////

    function test_deploy() public {
        vm.prank(address(1));
        address community = factory.deploy("test", address(accessControl));

        assertEq(ThriveProtocolCommunity(community).name(), "test");
    }

    function test_deploy_withoutRole() public {
        vm.prank(address(2));
        vm.expectRevert("ThriveProtocolCommunity: must have admin role");
        factory.deploy("test", address(accessControl));

        vm.prank(address(1));
        accessControl.grantRole(0x00, address(2));

        vm.prank(address(2));
        address community = factory.deploy("test", address(accessControl));

        assertEq(ThriveProtocolCommunity(community).name(), "test");
    }

    /////////////
    // setters //
    /////////////

    function test_setAdmins() public {
        vm.prank(address(1));
        factory.setAdmins(address(2), address(3), address(4), address(5));

        assertEq(factory.rewardsAdmin(), address(2));
        assertEq(factory.treasuryAdmin(), address(3));
        assertEq(factory.validationsAdmin(), address(4));
        assertEq(factory.foundationAdmin(), address(5));
    }

    function test_setAdmins_withoutRole() public {
        vm.prank(address(2));
        vm.expectRevert("ThriveProtocolCommunity: must have admin role");
        factory.setAdmins(address(2), address(3), address(4), address(5));

        vm.prank(address(1));
        accessControl.grantRole(0x00, address(2));
        vm.prank(address(2));
        factory.setAdmins(address(2), address(3), address(4), address(5));
        assertEq(factory.rewardsAdmin(), address(2));
    }

    function test_setPercents() public {
        vm.prank(address(1));
        factory.setPercentage(90, 1, 1, 8);

        assertEq(factory.rewardsPercentage(), 90);
        assertEq(factory.treasuryPercentage(), 1);
        assertEq(factory.validationsPercentage(), 1);
        assertEq(factory.foundationPercentage(), 8);
    }

    function test_setPercents_withoutRole() public {
        vm.prank(address(2));
        vm.expectRevert("ThriveProtocolCommunity: must have admin role");
        factory.setPercentage(90, 1, 1, 8);

        vm.prank(address(1));
        accessControl.grantRole(0x00, address(2));
        vm.prank(address(2));
        factory.setPercentage(90, 1, 1, 8);
        assertEq(factory.rewardsPercentage(), 90);
    }

    function test_setAccessControl() public {
        MockAccessControl newAccessControl = new MockAccessControl();

        vm.prank(address(1));
        factory.setAccessControlEnumerable(address(newAccessControl));

        address accessAddress = address(factory.accessControlEnumerable());
        assertEq(accessAddress, address(newAccessControl));
    }

    function test_setAccessControl_withoutRole() public {
        MockAccessControl newAccessControl = new MockAccessControl();

        vm.startPrank(address(2));
        vm.expectRevert("ThriveProtocolCommunity: must have admin role");
        factory.setAccessControlEnumerable(address(newAccessControl));
    }

    /////////////
    // getters //
    /////////////

    function test_getAdmins() public view {
        assertEq(factory.rewardsAdmin(), rewardsAdmin);
        assertEq(factory.treasuryAdmin(), treasuryAdmin);
        assertEq(factory.validationsAdmin(), validationsAdmin);
        assertEq(factory.foundationAdmin(), foundationAdmin);
    }

    function test_getPercents() public view {
        assertEq(factory.rewardsPercentage(), 80);
        assertEq(factory.treasuryPercentage(), 5);
        assertEq(factory.validationsPercentage(), 5);
        assertEq(factory.foundationPercentage(), 10);
    }
}
