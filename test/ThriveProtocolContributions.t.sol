//SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveProtocolContributions} from "src/ThriveProtocolContributions.sol";
import "test/mock/MockAccessControl.sol";

contract ThriveProtocolContributionsTest is Test {
    bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");

    MockAccessControl accessControl;
    
    event ContributionAdded(
        uint indexed _id,
        address indexed _owner,
        string _community,
        string _community_chain,
        string _metadata_identifier,
        address indexed _validator,
        uint _reward,
        uint _validation_reward
    );
    event ContributionDeactivated(uint indexed _id);

    ThriveProtocolContributions contributions;

    function setUp() public {
        vm.startPrank(address(6));
        accessControl = new MockAccessControl();
        accessControl.grantRole(ADMIN_ROLE, address(1));
        vm.stopPrank();
        contributions = new ThriveProtocolContributions(address(accessControl), ADMIN_ROLE);
    }

    function test_contributionCount() public {
        assertEq(contributions.contributionCount(), 0);

        contributions.addContribution(
            "test", "test_chain", "test_metadata", address(1), 100, 10
        );
        assertEq(contributions.contributionCount(), 1);
    }

    function test_addContribution() public {
        vm.startPrank(address(1));
        vm.expectEmit(true, true, true, true);
        emit ContributionAdded(
            0,
            address(1),
            "test",
            "test_chain",
            "test_metadata",
            address(2),
            100,
            10
        );
        bool res = contributions.addContribution(
            "test", "test_chain", "test_metadata", address(2), 100, 10
        );
        vm.stopPrank();

        assertEq(contributions.contributionCount(), 1);
        assertEq(res, true);
    }

    function test_getContribution() public {
        test_addContribution();

        (
            address owner,
            string memory comminity,
            string memory community_chain,
            string memory metadata_identifier,
            address validator,
            uint reward,
            uint validation_reward,
            ThriveProtocolContributions.Status status
        ) = contributions.getContribution(0);

        assertEq(owner, address(1));
        assertEq(comminity, "test");
        assertEq(community_chain, "test_chain");
        assertEq(metadata_identifier, "test_metadata");
        assertEq(validator, address(2));
        assertEq(reward, 100);
        assertEq(validation_reward, 10);
        assertEq(uint256(status), uint256(ThriveProtocolContributions.Status(0)));
    }

    function test_deactivateContribution() public {
        test_addContribution();

        vm.startPrank(address(1));
        vm.expectEmit(true, true, true, true);
        emit ContributionDeactivated(0);
        contributions.deactivateContribution(0);

        (
            ,,,,,,,ThriveProtocolContributions.Status status
        ) = contributions.getContribution(0);
        vm.stopPrank();
        assertEq(uint256(status), uint256(ThriveProtocolContributions.Status(1)));
    }

    function test_deactivateContribution_FromNotOwner() public {
        test_addContribution();

        vm.startPrank(address(2));
        vm.expectRevert("ThriveProtocol: not an owner");
        contributions.deactivateContribution(0);
        vm.stopPrank();
    }

    function test_deactivateContribution_AlreadyDeactivated() public {
        test_addContribution();

        vm.startPrank(address(1));
        contributions.deactivateContribution(0);
        
        vm.expectRevert("ThriveProtocol: contribution already deactivated");
        contributions.deactivateContribution(0);
        vm.stopPrank();
    }

    function test_setAccessControl() public {
        MockAccessControl newAccessControl = new MockAccessControl();

        vm.prank(address(1));
        contributions.setAccessControlEnumerable(address(newAccessControl), 0x0000000000000000000000000000000000000000000000000000000000000111);

        address accessAddress = address(contributions.accessControlEnumerable());
        assertEq(accessAddress, address(newAccessControl));
        assertEq(contributions.adminRole(), 0x0000000000000000000000000000000000000000000000000000000000000111);
    }

    function test_sAccessControl_fromNotAdmin() public {
        MockAccessControl newAccessControl = new MockAccessControl();

        vm.startPrank(address(2));
        vm.expectRevert("ThriveProtocol: must have admin role");
        contributions.setAccessControlEnumerable(address(newAccessControl), 0x0000000000000000000000000000000000000000000000000000000000000111);
    }
}
