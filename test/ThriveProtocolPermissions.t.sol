//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveProtocolPermissions} from "src/ThriveProtocolPermissions.sol";
import {MockAccessControl} from "test/mock/MockAccessControl.sol";

contract ThriveProtocolPermissionsTest is Test {
    ThriveProtocolPermissions private permissions;
    MockAccessControl private accessControl;
    bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");

    function setUp() public {
        vm.startPrank(address(1));
        accessControl = new MockAccessControl();
        accessControl.grantRole(ADMIN_ROLE, address(2));
        vm.stopPrank();

        permissions = new ThriveProtocolPermissions(address(accessControl), ADMIN_ROLE, address(2));
    }

    function test_addCommuniityAdmin() public {
        vm.prank(address(2));
        permissions.addCommunityAdmin("0123", "test", address(3));

        assertEq(permissions.communityAdmins("0123", "test"), address(3));
    }

    function test_addCommunityAdmin_withoutRole() public {
        vm.startPrank(address(3));
        vm.expectRevert("ThriveProtocol: must have admin role");
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
        vm.expectRevert("ThriveProtocol: must have admin role");
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

    function test_setAccessControl() public {
        MockAccessControl newAccessControl = new MockAccessControl();

        vm.prank(address(2));
        permissions.setAccessControlEnumerable(
            address(newAccessControl),
            0x0000000000000000000000000000000000000000000000000000000000000111
        );

        address accessAddress = address(permissions.accessControlEnumerable());
        assertEq(accessAddress, address(newAccessControl));
        assertEq(
            permissions.adminRole(),
            0x0000000000000000000000000000000000000000000000000000000000000111
        );
    }

    function test_sAccessControl_fromNotAdmin() public {
        MockAccessControl newAccessControl = new MockAccessControl();

        vm.startPrank(address(3));
        vm.expectRevert("ThriveProtocol: must have admin role");
        permissions.setAccessControlEnumerable(
            address(newAccessControl),
            0x0000000000000000000000000000000000000000000000000000000000000111
        );
    }
}