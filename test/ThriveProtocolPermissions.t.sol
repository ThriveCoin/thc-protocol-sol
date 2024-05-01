//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveProtocolPermissions} from "src/ThriveProtocolPermissions.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";

contract ThriveProtocolPermissionsTest is Test {
    bytes32 public constant PERMISSIONS_CONTRACT =
        keccak256("PERMISSIONS_CONTRACT");

    ThriveProtocolPermissions private permissions;
    ThriveProtocolAccessControl private accessControl;

    function setUp() public {
        vm.prank(address(1));
        accessControl = new ThriveProtocolAccessControl();

        permissions =
            new ThriveProtocolPermissions(address(2), address(accessControl));

        vm.prank(address(1));
        accessControl.grantRole(PERMISSIONS_CONTRACT, address(permissions));
    }

    function test_createRole() public {
        vm.prank(address(1));
        bytes32 role = permissions.createRole(0x00, "0x34", "MANAGER", 0x00);

        vm.prank(address(1));
        accessControl.grantRole(role, address(2));
        assertEq(accessControl.hasRole(role, address(2)), true);
    }

    function test_createRole_withoutRole() public {
        vm.startPrank(address(2));
        vm.expectRevert("ThriveProtocol: must have role");
        permissions.createRole(0x00, "0x34", "MANAGER", 0x00);
    }

    function test_grantRole() public {
        vm.startPrank(address(1));
        bytes32 role = permissions.createRole(0x00, "0x34", "MANAGER", 0x00);
        accessControl.grantRole(role, address(2));
        bytes32 testRole = permissions.createRole(0x00, "0x34", "TEST", 0x00);
        vm.stopPrank();

        vm.prank(address(2));
        permissions.grantRole(0x00, "0x34", "TEST", address(3));

        assertEq(accessControl.hasRole(testRole, address(3)), true);
    }

    function test_grantRole_withouAdminRole() public {
        vm.startPrank(address(1));
        bytes32 role = permissions.createRole(0x00, "0x34", "MANAGER", 0x00);
        accessControl.grantRole(role, address(2));
        permissions.createRole(0x00, "0x34", "TEST", 0x00);
        vm.stopPrank();

        vm.startPrank(address(3));
        vm.expectRevert("ThriveProtocol: must have MANAGER role");
        permissions.grantRole(0x00, "0x34", "TEST", address(3));
    }

    function test_checkRootAdmin() public view {
        assertEq(permissions.rootAdmin(), address(2));
    }

    function test_addCommuniityAdmin() public {
        vm.prank(address(2));
        permissions.addCommunityAdmin("0123", "test", address(3));

        assertEq(permissions.communityAdmins("0123", "test"), address(3));
    }

    function test_addCommunityAdmin_withoutRole() public {
        vm.startPrank(address(3));
        vm.expectRevert("ThriveProtocol: not a root admin");
        permissions.addCommunityAdmin("0123", "test", address(3));
        vm.stopPrank();
    }

    function test_removeCommunityAdmin() public {
        vm.prank(address(2));
        permissions.addCommunityAdmin("0123", "test", address(3));

        assertEq(permissions.communityAdmins("0123", "test"), address(3));

        vm.prank(address(2));
        permissions.removeCommunityAdmin("0123", "test");
        assertEq(permissions.communityAdmins("0123", "test"), address(0));
    }

    function test_removeCommunityAdmin_withoutRole() public {
        vm.prank(address(2));
        permissions.addCommunityAdmin("0123", "test", address(3));

        vm.startPrank(address(3));
        vm.expectRevert("ThriveProtocol: not a root admin");
        permissions.removeCommunityAdmin("0123", "test");
        vm.stopPrank();
    }

    function test_checkCommunityAdmin() public {
        test_addCommuniityAdmin();

        assertEq(permissions.checkAdmin("0123", "test", address(3)), true);
    }

    function test_checkCommunityAdmin_fromNotAdmin() public {
        vm.expectRevert("ThriveProtocol: not an community admin");
        permissions.checkAdmin("0123", "test", address(3));
    }
}
