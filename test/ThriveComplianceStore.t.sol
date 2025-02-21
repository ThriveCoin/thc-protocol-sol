// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveComplianceStore} from "src/ThriveComplianceStore.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";

contract ThriveComplianceStoreTest is Test {
    ThriveComplianceStore complianceStore;
    ThriveProtocolAccessControl public accessControl;

    address owner = address(1);
    address admin = address(2);
    address user = address(3);
    bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 constant CHECK_TYPE_KYC = 1;
    uint256 constant VALIDITY_DURATION = 7 days;

    function setUp() public {
        vm.startPrank(owner);

        ThriveProtocolAccessControl accessControlImpl =
            new ThriveProtocolAccessControl();
        bytes memory accessControlData =
            abi.encodeCall(accessControlImpl.initialize, ());
        address accessControlProxy = address(
            new ERC1967Proxy(address(accessControlImpl), accessControlData)
        );
        accessControl = ThriveProtocolAccessControl(accessControlProxy);
        accessControl = ThriveProtocolAccessControl(accessControlProxy);
        accessControl.grantRole(ADMIN_ROLE, address(1));

        complianceStore = new ThriveComplianceStore();
        complianceStore.initialize(address(accessControlProxy), ADMIN_ROLE);
        vm.stopPrank();
    }

    function test_initialization() public view {
        assertEq(complianceStore.role(), ADMIN_ROLE);
    }

    function test_setCheckTypeValidityDuration_asAdmin() public {
        vm.prank(owner);
        complianceStore.setCheckTypeValidityDuration(
            CHECK_TYPE_KYC, VALIDITY_DURATION
        );
        assertEq(
            complianceStore.checkTypeValidityDurations(CHECK_TYPE_KYC),
            VALIDITY_DURATION
        );
    }

    function test_setCheckTypeValidityDuration_asNonAdmin() public {
        vm.prank(user);
        vm.expectRevert();
        complianceStore.setCheckTypeValidityDuration(
            CHECK_TYPE_KYC, VALIDITY_DURATION
        );
    }

    function test_setComplianceCheck_asAdmin() public {
        vm.startPrank(owner);
        complianceStore.setCheckTypeValidityDuration(
            CHECK_TYPE_KYC, VALIDITY_DURATION
        );
        complianceStore.setComplianceCheck(CHECK_TYPE_KYC, user, true);
        vm.stopPrank();

        (bool passed, uint256 updatedAt) =
            complianceStore.complianceChecks(CHECK_TYPE_KYC, user);
        assertTrue(passed);
        assertGt(updatedAt, 0);
    }

    function test_setComplianceCheck_asNonAdmin() public {
        vm.prank(user);
        vm.expectRevert();
        complianceStore.setComplianceCheck(CHECK_TYPE_KYC, user, true);
    }

    function test_removeComplianceCheck_asAdmin() public {
        vm.startPrank(owner);
        complianceStore.setCheckTypeValidityDuration(
            CHECK_TYPE_KYC, VALIDITY_DURATION
        );
        complianceStore.setComplianceCheck(CHECK_TYPE_KYC, user, true);
        complianceStore.removeComplianceCheck(CHECK_TYPE_KYC, user);
        vm.stopPrank();

        (bool passed,) = complianceStore.complianceChecks(CHECK_TYPE_KYC, user);
        assertFalse(passed);
    }

    function test_removeComplianceCheck_asNonAdmin() public {
        vm.prank(user);
        vm.expectRevert();
        complianceStore.removeComplianceCheck(CHECK_TYPE_KYC, user);
    }

    function test_passedComplianceCheck_withValidCheck() public {
        vm.startPrank(owner);
        complianceStore.setCheckTypeValidityDuration(
            CHECK_TYPE_KYC, VALIDITY_DURATION
        );
        complianceStore.setComplianceCheck(CHECK_TYPE_KYC, user, true);
        vm.stopPrank();

        assertTrue(complianceStore.passedComplianceCheck(CHECK_TYPE_KYC, user));
    }

    function test_passedComplianceCheck_withExpiredCheck() public {
        vm.startPrank(owner);
        complianceStore.setCheckTypeValidityDuration(CHECK_TYPE_KYC, 1);
        complianceStore.setComplianceCheck(CHECK_TYPE_KYC, user, true);
        vm.warp(block.timestamp + 2);
        vm.stopPrank();

        assertFalse(complianceStore.passedComplianceCheck(CHECK_TYPE_KYC, user));
    }

    function test_passedComplianceCheck_withNoCheck() public view {
        assertFalse(complianceStore.passedComplianceCheck(CHECK_TYPE_KYC, user));
    }
}
