// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import "../src/ThriveWorkerUnit.sol";
import {MockERC20} from "test/mock/MockERC20.sol";

contract ThriveWorkerUnitTest is Test {
    ThriveWorkerUnit public thriveWorkerUnit;
    MockERC20 public mockToken;
    address public moderator;
    address[] public validators;
    address public badgeQuery = address(0x123456);

    function setUp() public {
        moderator = address(this);
        validators.push(address(0x1));
        validators.push(address(0x2));

        mockToken = new MockERC20("MockToken", "MKT");
        mockToken.mint(address(this), 1_000_000 ether);

        thriveWorkerUnit = new ThriveWorkerUnit(
            moderator, // Moderator address
            address(mockToken), // Reward token address
            10, // Reward amount per user
            100 ether, // Max rewards
            1,
            block.timestamp + 1 days, // Deadline
            2, // Max completions per user
            validators, // Validators
            "ValidationMetadata", // Validation metadata
            "Task metadata", // Metadata
            badgeQuery // Badge query address
        );

        mockToken.transfer(address(thriveWorkerUnit), 1_000 ether);
        mockToken.approve(address(thriveWorkerUnit), 1_000 ether);

        thriveWorkerUnit.initialize{value: 100 ether}();
    }

    function testConstructorRequirements() public {
        vm.expectRevert("ThriveProtocol: moderator address is required");
        new ThriveWorkerUnit(
            address(0),
            address(mockToken),
            10,
            100 ether,
            1,
            block.timestamp + 1 days,
            2,
            validators,
            "ValidationMetadata",
            "Task metadata",
            badgeQuery
        );

        vm.expectRevert("ThriveProtocol: badgeQuery address is required");
        new ThriveWorkerUnit(
            moderator,
            address(mockToken),
            10,
            100 ether,
            1,
            block.timestamp + 1 days,
            2,
            validators,
            "ValidationMetadata",
            "Task metadata",
            address(0)
        );

        vm.expectRevert("ThriveProtocol: invalid reward amount!");
        new ThriveWorkerUnit(
            moderator,
            address(mockToken),
            0,
            100 ether,
            1,
            block.timestamp + 1 days,
            2,
            validators,
            "ValidationMetadata",
            "Task metadata",
            badgeQuery
        );

        vm.expectRevert("ThriveProtocol: invalid validation reward amount!");
        new ThriveWorkerUnit(
            moderator,
            address(mockToken),
            10,
            100 ether,
            0,
            block.timestamp + 1 days,
            2,
            validators,
            "ValidationMetadata",
            "Task metadata",
            badgeQuery
        );
    }

    function testInitializeRequirements() public {
        ThriveWorkerUnit newWorkerUnit = new ThriveWorkerUnit(
            moderator,
            address(mockToken),
            10,
            100 ether,
            1,
            block.timestamp + 1 days,
            2,
            validators,
            "ValidationMetadata",
            "Task metadata",
            badgeQuery
        );

        mockToken.approve(address(newWorkerUnit), 1_000 ether);

        // case: already initialized
        newWorkerUnit.initialize{value: 100 ether}();
        vm.expectRevert("ThriveProtocol: already initialized");
        newWorkerUnit.initialize{value: 100 ether}();

        // case: validation reward amount not set
        ThriveWorkerUnit uninitializedWorkerUnit = new ThriveWorkerUnit(
            moderator,
            address(mockToken),
            10,
            100 ether,
            1,
            block.timestamp + 1 days,
            2,
            validators,
            "ValidationMetadata",
            "Task metadata",
            badgeQuery
        );

        mockToken.approve(address(uninitializedWorkerUnit), 1_000 ether);

        // case: insufficient value for validators and contributors
        vm.expectRevert(
            "ThriveProtocol: insufficient value for validators and contributors"
        );
        uninitializedWorkerUnit.initialize{value: 1 ether}();
    }

    function testInitialization() public view {
        assertEq(thriveWorkerUnit.rewardAmount(), 10);
        assertEq(thriveWorkerUnit.maxRewards(), 100 ether);
        assertEq(thriveWorkerUnit.status(), "active");

        address[] memory validatorList = thriveWorkerUnit.getValidators();
        assertEq(validatorList[0], validators[0]);
        assertEq(validatorList[1], validators[1]);

        assertEq(address(thriveWorkerUnit).balance, 100 ether);
    }

    function testConfirmRequirements() public {
        thriveWorkerUnit.addRequiredBadge(keccak256("TestBadge"));

        vm.mockCall(
            badgeQuery,
            abi.encodeWithSelector(IBadgeQuery.hasBadge.selector),
            abi.encode(true)
        );

        // case: work unit expired
        vm.warp(block.timestamp + 2 days);
        address contributor = address(0xdead);
        vm.prank(validators[0]);

        vm.expectRevert("ThriveProtocol: work unit has expired");

        thriveWorkerUnit.confirm(contributor, "TestMetadata");

        // case: max completions per user reached
        vm.warp(block.timestamp - 2 days);
        for (uint256 i = 0; i < 2; i++) {
            vm.prank(validators[0]);
            thriveWorkerUnit.confirm(contributor, "TestMetadata");
        }
        vm.prank(validators[0]);

        vm.expectRevert("ThriveProtocol: max completions per user reached");

        thriveWorkerUnit.confirm(contributor, "TestMetadata");

        // case: contributor is not the assigned address
        thriveWorkerUnit.setMaxCompletionsPerUser(10);
        thriveWorkerUnit.setAssignedAddress(address(0x123));

        vm.prank(validators[0]);
        vm.expectRevert(
            "ThriveProtocol: contributor is not the assigned address"
        );

        thriveWorkerUnit.confirm(contributor, "TestMetadata");
        thriveWorkerUnit.setAssignedAddress(contributor);

        // case: required badge is missing
        vm.mockCall(
            badgeQuery,
            abi.encodeWithSelector(IBadgeQuery.hasBadge.selector),
            abi.encode(false)
        );
        vm.prank(validators[0]);

        vm.expectRevert("ThriveProtocol: required badge is missing!");

        thriveWorkerUnit.confirm(contributor, "TestMetadata");
    }

    function testConfirm() public {
        thriveWorkerUnit.addRequiredBadge(keccak256("TestBadge"));

        vm.mockCall(
            badgeQuery,
            abi.encodeWithSelector(IBadgeQuery.hasBadge.selector),
            abi.encode(true)
        );

        assertEq(thriveWorkerUnit.status(), "active");

        address contributor = address(0xdead);
        vm.prank(validators[0]);
        thriveWorkerUnit.confirm(contributor, "TestMetadata");

        assertEq(thriveWorkerUnit.completions(contributor), 1);
        assertEq(
            mockToken.balanceOf(contributor),
            thriveWorkerUnit.rewardAmount()
        );
        assertEq(
            mockToken.balanceOf(address(thriveWorkerUnit)),
            2_000 ether - thriveWorkerUnit.rewardAmount()
        );
    }

    function testBadgeRequirement() public {
        thriveWorkerUnit.addRequiredBadge(keccak256("TestBadge"));

        vm.mockCall(
            badgeQuery,
            abi.encodeWithSelector(IBadgeQuery.hasBadge.selector),
            abi.encode(false)
        );

        address contributor = address(0xdead);

        vm.prank(validators[0]);
        vm.expectRevert("ThriveProtocol: required badge is missing!");

        thriveWorkerUnit.confirm(contributor, "TestMetadata");
    }

    function testDeadlineEnforcement() public {
        vm.warp(block.timestamp + 2 days);

        address contributor = address(0xdead);

        vm.prank(validators[0]);
        vm.expectRevert("ThriveProtocol: work unit has expired");

        thriveWorkerUnit.confirm(contributor, "TestMetadata");
    }

    function testGetValidators() public view {
        address[] memory validatorList = thriveWorkerUnit.getValidators();

        assertEq(validatorList.length, validators.length);
    }

    function testExceedMaxCompletions() public {
        thriveWorkerUnit.addRequiredBadge(keccak256("TestBadge"));

        vm.mockCall(
            badgeQuery,
            abi.encodeWithSelector(IBadgeQuery.hasBadge.selector),
            abi.encode(true)
        );
        address contributor = address(0xdead);
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(validators[0]);
            if (i == 2) {
                vm.expectRevert(
                    "ThriveProtocol: max completions per user reached"
                );
            }
            thriveWorkerUnit.confirm(contributor, "TestMetadata");
        }
    }

    function testUnReadyContract() public {
        ThriveWorkerUnit newWorkerUnit = new ThriveWorkerUnit(
            moderator,
            address(mockToken),
            10,
            100 ether,
            1,
            block.timestamp + 1 days,
            2,
            validators,
            "ValidationMetadata",
            "Task metadata",
            badgeQuery
        );
        address contributor = address(0xdead);

        // only validator error
        vm.expectRevert(
            "ThriveProtocol: only a validator can perform this action"
        );
        newWorkerUnit.confirm(contributor, "TestMetadata");

        // not ready error
        vm.prank(validators[0]);
        vm.expectRevert("ThriveProtocol: contract is not ready");
        newWorkerUnit.confirm(contributor, "TestMetadata");
    }

    function testSetAssignedAddress() public {
        address newAddress = address(0x123);

        thriveWorkerUnit.setAssignedAddress(newAddress);

        assertEq(thriveWorkerUnit.assignedAddress(), newAddress);
    }

    function testSetAssignedAddressToZero() public {
        address newAddress = address(0);

        vm.expectRevert("ThriveProtocol: invalid address!");

        thriveWorkerUnit.setAssignedAddress(newAddress);
    }

    function testRemoveRequiredBadge() public {
        bytes32 badge = keccak256("TestBadge");

        thriveWorkerUnit.addRequiredBadge(badge);
        thriveWorkerUnit.removeRequiredBadge(badge);
        bytes32[] memory badges = thriveWorkerUnit.getRequiredBadges();

        assertEq(badges.length, 0);
    }

    function testRemoveNonExistentBadge() public {
        bytes32 badge = keccak256("NonExistentBadge");

        vm.expectRevert("ThriveProtocol: badge does not exist");

        thriveWorkerUnit.removeRequiredBadge(badge);
    }

    function testSetValidationMetadata() public {
        string memory newMetadata = "NewValidationMetadata";

        thriveWorkerUnit.setValidationMetadata(newMetadata);

        assertEq(thriveWorkerUnit.validationMetadata(), newMetadata);
    }

    function testSetMetadataVersion() public {
        string memory newVersion = "2.0";

        thriveWorkerUnit.setMetadataVersion(newVersion);

        assertEq(thriveWorkerUnit.metadataVersion(), newVersion);
    }

    function testSetMetadata() public {
        string memory newMetadata = "NewTaskMetadata";

        thriveWorkerUnit.setMetadata(newMetadata);

        assertEq(thriveWorkerUnit.metadata(), newMetadata);
    }

    function testSetDeadline() public {
        uint256 newDeadline = block.timestamp + 3 days;

        thriveWorkerUnit.setDeadline(newDeadline);

        assertEq(thriveWorkerUnit.deadline(), newDeadline);
    }

    function testSetMaxCompletionsPerUser() public {
        uint256 newMaxCompletions = 5;

        thriveWorkerUnit.setMaxCompletionsPerUser(newMaxCompletions);

        assertEq(thriveWorkerUnit.maxCompletionsPerUser(), newMaxCompletions);
    }

    function testWithdrawRemainingRequirements() public {
        vm.expectRevert("ThriveProtocol: work unit is still active");

        thriveWorkerUnit.withdrawRemaining();
    }

    function testWithdrawRemaining() public {
        vm.warp(block.timestamp + 2 days);

        uint256 contractERC20Balance = mockToken.balanceOf(
            address(thriveWorkerUnit)
        );
        assertGt(contractERC20Balance, 0);

        thriveWorkerUnit.withdrawRemaining();

        uint256 moderatorERC20Balance = mockToken.balanceOf(moderator);
        assertNotEq(moderatorERC20Balance, contractERC20Balance);

        uint256 remainingERC20Balance = mockToken.balanceOf(
            address(thriveWorkerUnit)
        );
        assertEq(remainingERC20Balance, 0);

        uint256 remainingEtherBalance = address(thriveWorkerUnit).balance;
        assertEq(remainingEtherBalance, 0);
    }

    receive() external payable {}
}
