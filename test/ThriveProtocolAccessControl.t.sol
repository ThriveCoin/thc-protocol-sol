//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";

contract ThriveProtocolAccessControlTest is Test {
    ThriveProtocolAccessControl accessControl;

    bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 TEST_ROLE = keccak256("TEST_ROLE");
    bytes32 DEFAULT_ADMIN_ROLE = 0x00;

    function setUp() public {
        vm.startPrank(address(1));
        accessControl = new ThriveProtocolAccessControl();
        accessControl.initialize();
        vm.stopPrank();
    }

    function test_setAdminRole() public {
        vm.startPrank(address(1));
        accessControl.grantRole(ADMIN_ROLE, address(2));
        accessControl.setRoleAdmin(TEST_ROLE, ADMIN_ROLE);

        bytes4 selector = bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)"));
        vm.expectRevert(abi.encodeWithSelector(selector, address(1), ADMIN_ROLE));
        accessControl.grantRole(TEST_ROLE, address(3));
        vm.stopPrank();

        vm.prank(address(2));
        accessControl.grantRole(TEST_ROLE, address(3));
        assertEq(accessControl.hasRole(TEST_ROLE, address(3)), true);
    }

    function test_setAdminRole_fromNotDefaultAdmin() public {
        vm.startPrank(address(2));
        bytes4 selector = bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)"));
        vm.expectRevert(abi.encodeWithSelector(selector, address(2), DEFAULT_ADMIN_ROLE));
        accessControl.setRoleAdmin(TEST_ROLE, ADMIN_ROLE);
        vm.stopPrank();
    }
}