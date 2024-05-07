//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveProtocolPermissions} from "src/ThriveProtocolPermissions.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";

contract ThriveProtocolPermissionsTest is Test {
    ThriveProtocolPermissions private permissions;

    function setUp() public {
        vm.prank(address(1));
        permissions = new ThriveProtocolPermissions();
    }

    function test_createRole() public {
        vm.prank(address(1));
        bytes32 role =
            permissions.createRole(0x00, "0x34", "MANAGER", address(3));

        assertEq(permissions.hasRole(role, address(3)), true);
    }

    function test_createRole_withoutRole() public {
        vm.startPrank(address(3));
        vm.expectRevert("ThriveProtocol: must have role");
        permissions.createRole(0x00, "0x34", "MANAGER", address(2));
    }

    function test_setRoleAdmin() public {
        vm.startPrank(address(1));
        bytes32 role =
            permissions.createRole(0x00, "0x34", "MANAGER", address(2));
        bytes32 testRole =
            permissions.createRole(0x00, "0x34", "TEST", address(3));
        permissions.setRoleAdmin(testRole);
        vm.stopPrank();

        vm.prank(address(2));
        permissions.grantRole(testRole, address(4));
        assertEq(permissions.hasRole(testRole, address(4)), true);

        vm.startPrank(address(1));
        vm.expectRevert();
        permissions.grantRole(testRole, address(5));
        vm.stopPrank();

        assertEq(permissions.hasRole(testRole, address(3)), true);
        assertEq(permissions.getRoleAdmin(testRole), role);
    }

    function test_setRoleAdmin_withoutRole() public {
        vm.startPrank(address(1));
        bytes32 role =
            permissions.createRole(0x00, "0x34", "MANAGER", address(2));
        bytes32 testRole =
            permissions.createRole(0x00, "0x34", "TEST", address(3));
        vm.stopPrank();

        vm.startPrank(address(3));
        vm.expectRevert("ThriveProtocol: must have role");
        permissions.setRoleAdmin(testRole);
    }

    function test_grantRole_forNotCurrentCommunity() public {
        vm.startPrank(address(1));
        bytes32 role =
            permissions.createRole(0x00, "0x34", "MANAGER", address(2));
        bytes32 testRole =
            permissions.createRole(0x00, "0x34", "TEST", address(3));
        permissions.setRoleAdmin(testRole);

        bytes32 test2Role =
            permissions.createRole(0x00, "0x234", "TEST", address(4));
        vm.stopPrank();

        vm.startPrank(address(2));
        vm.expectRevert();
        permissions.grantRole(test2Role, address(5));
        vm.stopPrank();
    }

    function test_addCommuniityAdmin() public {
        vm.prank(address(1));
        permissions.addCommunityAdmin("0123", "test", address(3));

        assertEq(permissions.communityAdmins("0123", "test"), address(3));
    }

    function test_addCommunityAdmin_withoutRole() public {
        vm.startPrank(address(3));
        vm.expectRevert("ThriveProtocol: must have role");
        permissions.addCommunityAdmin("0123", "test", address(3));
        vm.stopPrank();
    }

    function test_removeCommunityAdmin() public {
        vm.prank(address(1));
        permissions.addCommunityAdmin("0123", "test", address(3));

        assertEq(permissions.communityAdmins("0123", "test"), address(3));

        vm.prank(address(1));
        permissions.removeCommunityAdmin("0123", "test");
        assertEq(permissions.communityAdmins("0123", "test"), address(0));
    }

    function test_removeCommunityAdmin_withoutRole() public {
        vm.prank(address(1));
        permissions.addCommunityAdmin("0123", "test", address(3));

        vm.startPrank(address(3));
        vm.expectRevert("ThriveProtocol: must have role");
        permissions.removeCommunityAdmin("0123", "test");
        vm.stopPrank();
    }
}
