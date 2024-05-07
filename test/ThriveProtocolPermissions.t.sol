//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveProtocolPermissions} from "src/ThriveProtocolPermissions.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";
import "openzeppelin-contracts/contracts/access/IAccessControl.sol";

contract ThriveProtocolPermissionsTest is Test {
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

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
        bytes4 selector = bytes4(
            keccak256("AccessControlUnauthorizedAccount(address,bytes32)")
        );
        vm.expectRevert(abi.encodeWithSelector(selector, address(3), 0x00));
        permissions.createRole(0x00, "0x34", "MANAGER", address(2));
    }

    function test_setRoleAdmin() public {
        vm.startPrank(address(1));
        bytes32 role =
            permissions.createRole(0x00, "0x34", "MANAGER", address(2));
        bytes32 testRole =
            permissions.createRole(0x00, "0x34", "TEST", address(3));
        permissions.setRoleAdmin(testRole, "MANAGER");
        vm.stopPrank();

        vm.prank(address(2));
        permissions.grantRole(testRole, address(4));
        assertEq(permissions.hasRole(testRole, address(4)), true);

        vm.startPrank(address(1));
         bytes4 selector = bytes4(
            keccak256("AccessControlUnauthorizedAccount(address,bytes32)")
        );
        vm.expectRevert(abi.encodeWithSelector(selector, address(1), role));
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
         bytes4 selector = bytes4(
            keccak256("AccessControlUnauthorizedAccount(address,bytes32)")
        );
        vm.expectRevert(abi.encodeWithSelector(selector, address(3), 0x00));
        permissions.setRoleAdmin(testRole, "MANAGER");
    }

    function test_grantRole_forNotCurrentCommunity() public {
        vm.startPrank(address(1));
        bytes32 role =
            permissions.createRole(0x00, "0x34", "MANAGER", address(2));
        bytes32 testRole =
            permissions.createRole(0x00, "0x34", "TEST", address(3));
        permissions.setRoleAdmin(testRole, "MANAGER");

        bytes32 test2Role =
            permissions.createRole(0x00, "0x234", "TEST", address(4));

        bytes32 test2AdminRole = permissions.createRole(0x00, "0x234", "MANAGER", address(4));

        permissions.setRoleAdmin(test2Role, "MANAGER");
        vm.stopPrank();

        vm.startPrank(address(2));
         bytes4 selector = bytes4(
            keccak256("AccessControlUnauthorizedAccount(address,bytes32)")
        );
        vm.expectRevert(abi.encodeWithSelector(selector, address(2), test2AdminRole));
        permissions.grantRole(test2Role, address(5));
        vm.stopPrank();
    }
}
