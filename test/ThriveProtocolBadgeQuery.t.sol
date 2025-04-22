// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/ThriveProtocolBadgeQuery.sol";
import "../src/ThriveProtocolAccessControl.sol";

contract ThriveProtocolBadgeQueryTest is Test {
    ThriveProtocolBadgeQuery public badgeQuery;
    ThriveProtocolAccessControl public accessControl;

    address public owner = address(0xA11CE);
    address public admin = address(0xB0B);
    address public user = address(0xC0DE);

    bytes32 public constant BADGE_ADMIN_ROLE = keccak256("BADGE_ADMIN_ROLE");
    bytes32 public constant TEST_BADGE_ID = keccak256("example-badge");

    function setUp() public {
        vm.startPrank(owner);

        accessControl = new ThriveProtocolAccessControl();
        accessControl.initialize();

        accessControl.grantRole(BADGE_ADMIN_ROLE, admin);

        badgeQuery = new ThriveProtocolBadgeQuery();
        badgeQuery.initialize(address(accessControl), BADGE_ADMIN_ROLE);

        vm.stopPrank();
    }

    function testInitialSetup() public view {
        assertEq(
            address(badgeQuery.accessControlEnumerable()),
            address(accessControl)
        );
        assertEq(badgeQuery.adminRole(), BADGE_ADMIN_ROLE);
    }

    function testGrantBadgeByAdmin() public {
        vm.prank(admin);
        badgeQuery.grantBadge(user, TEST_BADGE_ID);

        bool has = badgeQuery.hasBadge(user, TEST_BADGE_ID);

        assertTrue(has);
    }

    function testRevokeBadgeByAdmin() public {
        vm.prank(admin);
        badgeQuery.grantBadge(user, TEST_BADGE_ID);

        vm.prank(admin);
        badgeQuery.revokeBadge(user, TEST_BADGE_ID);
        bool has = badgeQuery.hasBadge(user, TEST_BADGE_ID);

        assertFalse(has);
    }

    function testOwnerCanUpdateAccessControl() public {
        ThriveProtocolAccessControl newAC = new ThriveProtocolAccessControl();
        newAC.initialize();

        vm.prank(owner);
        badgeQuery.setAccessControlEnumerable(address(newAC), BADGE_ADMIN_ROLE);

        assertEq(address(badgeQuery.accessControlEnumerable()), address(newAC));
    }

    function testEvents() public {
        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit ThriveProtocolBadgeQuery.BadgeGranted(user, TEST_BADGE_ID);
        badgeQuery.grantBadge(user, TEST_BADGE_ID);
    }
}
