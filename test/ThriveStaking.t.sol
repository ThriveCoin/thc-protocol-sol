// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveStakingNative} from "../src/ThriveStakingNative.sol";
import {ThriveStakingIERC20} from "../src/ThriveStakingIERC20.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";
import {MockERC20} from "test/mock/MockERC20.sol";

/// @dev Test suite for native token staking.
contract ThriveStakingNativeTest is Test {
    ThriveStakingNative staking;
    ThriveProtocolAccessControl public accessControl;
    address admin = address(0xABCD);
    address user = address(0xBEEF);
    uint256 yieldRate = 100;
    uint256 minStakingAmount = 1 ether;
    bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    function setUp() public {
        ThriveProtocolAccessControl accessControlImpl =
            new ThriveProtocolAccessControl();
        bytes memory accessControlData =
            abi.encodeCall(accessControlImpl.initialize, ());
        address accessControlProxy = address(
            new ERC1967Proxy(address(accessControlImpl), accessControlData)
        );
        accessControl = ThriveProtocolAccessControl(accessControlProxy);
        accessControl.grantRole(ADMIN_ROLE, admin);

        staking = new ThriveStakingNative();
        staking.initialize(
            yieldRate, minStakingAmount, address(accessControl), ADMIN_ROLE
        );
    }

    function testInitialize() public view {
        assertEq(staking.yieldRate(), yieldRate);
        assertEq(staking.minStakingAmount(), minStakingAmount);
        assertEq(staking.token(), address(0));
    }

    function testStakeRevertsForValueMismatch() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert("ThriveProtocol: Amount mismatch with value sent");
        staking.stake{value: 0.5 ether}(1 ether);
    }

    function testStakeRevertsForBelowMin() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert("ThriveProtocol: below minimum stake");
        staking.stake{value: 0.5 ether}(0.5 ether);
    }

    function testStakeSuccess() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        (uint256 amount, uint256 stakingTime, uint256 lastYieldTime) =
            staking.stakers(user);

        assertEq(amount, minStakingAmount);
        assertGt(stakingTime, 0);
        assertGt(lastYieldTime, 0);
    }

    function testGetStakedAmount() public {
        vm.deal(user, 10 ether);

        vm.prank(user);
        staking.stake{value: 1 ether}(1 ether);

        uint256 staked = staking.getStakedAmount(user);
        assertEq(staked, 1 ether);
    }

    function testCalculateYield() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        uint256 startTime = block.timestamp;

        vm.warp(startTime + 86400);
        uint256 yieldCalculated = staking.calculateYield(user);
        uint256 expected = (minStakingAmount * yieldRate * 86400) / 1e18;

        assertEq(yieldCalculated, expected);
    }

    function testClaimYieldRevertsIfNoStake() public {
        vm.prank(user);
        vm.expectRevert("ThriveProtocol: no staked tokens");
        staking.claimYield();
    }

    function testClaimYieldRevertsIfNoYield() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        vm.prank(user);
        vm.expectRevert("ThriveProtocol: no yield to claim");
        staking.claimYield();
    }

    function testClaimYieldSuccess() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        uint256 startTime = block.timestamp;

        vm.warp(startTime + 86400);
        uint256 yieldCalculated = staking.calculateYield(user);
        assertGt(yieldCalculated, 0);

        vm.prank(user);
        staking.claimYield();
        uint256 yieldAfter = staking.calculateYield(user);

        assertEq(yieldAfter, 0);
    }

    function testGetWithdrawalTimestampRevertsForNoStake() public {
        vm.prank(user);
        vm.expectRevert("ThriveProtocol: no staked tokens");
        staking.getWithdrawalTimestamp(user);
    }

    function testGetWithdrawalTimestampReturnsCorrectTimestamp() public {
        vm.deal(user, 10 ether);
        uint256 startTime = block.timestamp;
        vm.prank(user);
        staking.stake{value: 1 ether}(1 ether);

        uint256 withdrawalTimestamp = staking.getWithdrawalTimestamp(user);
        assertEq(withdrawalTimestamp, startTime + 30 days);
    }

    function testWithdrawRevertsBeforeLockup() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        vm.prank(user);
        vm.expectRevert("ThriveProtocol: 30-day lockup");
        staking.withdraw();
    }

    function testWithdrawSuccess() public {
        vm.deal(address(staking), 1_000 ether);
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        uint256 startTime = block.timestamp;

        vm.warp(startTime + 31 days);
        vm.prank(user);
        staking.withdraw();
        (uint256 amount, uint256 stakingTime, uint256 lastYieldTime) =
            staking.stakers(user);

        assertEq(amount, 0);
        assertEq(stakingTime, 0);
        assertEq(lastYieldTime, 0);
    }

    function testAdminFunctions() public {
        uint256 newYield = 200;
        vm.prank(admin);
        staking.setYieldRate(newYield);

        assertEq(staking.yieldRate(), newYield);

        uint256 newMin = 2 ether;
        vm.prank(admin);
        staking.setMinStakingAmount(newMin);

        assertEq(staking.minStakingAmount(), newMin);
    }

    function testNonAdminCannotCallAdminFunctions() public {
        vm.prank(user);
        vm.expectRevert();
        staking.setYieldRate(300);

        vm.prank(user);
        vm.expectRevert();
        staking.setMinStakingAmount(3 ether);
    }

    function testStakeRevertsIfPendingYieldExists() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        uint256 startTime = block.timestamp;

        vm.warp(startTime + 1000);
        vm.prank(user);
        vm.expectRevert(
            "ThriveProtocol: claim yield first and retry stake again"
        );
        staking.stake{value: minStakingAmount}(minStakingAmount);
    }

    function testSetAccessControlEnumerableRevertsForNonOwnerNative() public {
        vm.prank(user);
        vm.expectRevert();

        staking.setAccessControlEnumerable(address(0), bytes32("NEW_ROLE"));
    }

    function testSetAccessControlEnumerableSuccessNative() public {
        ThriveProtocolAccessControl newAccessControlImpl =
            new ThriveProtocolAccessControl();
        bytes memory data = abi.encodeCall(newAccessControlImpl.initialize, ());
        address newProxy =
            address(new ERC1967Proxy(address(newAccessControlImpl), data));
        bytes32 newAdminRole = keccak256("NEW_ROLE");

        staking.setAccessControlEnumerable(newProxy, newAdminRole);

        assertEq(staking.adminRole(), newAdminRole);
        assertEq(address(staking.accessControlEnumerable()), newProxy);
    }
}

/// @dev Test suite for ERC20 token staking.
contract ThriveStakingERC20Test is Test {
    ThriveStakingIERC20 staking;
    MockERC20 public mockToken;
    ThriveProtocolAccessControl public accessControl;
    address admin = address(0xABCD);
    address user = address(0xBEEF);
    uint256 yieldRate = 100;
    uint256 minStakingAmount = 1 ether;
    bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    function setUp() public {
        mockToken = new MockERC20("MockToken", "MKT");
        mockToken.mint(address(this), 100 ether);

        ThriveProtocolAccessControl accessControlImpl =
            new ThriveProtocolAccessControl();
        bytes memory accessControlData =
            abi.encodeCall(accessControlImpl.initialize, ());
        address accessControlProxy = address(
            new ERC1967Proxy(address(accessControlImpl), accessControlData)
        );
        accessControl = ThriveProtocolAccessControl(accessControlProxy);
        accessControl.grantRole(ADMIN_ROLE, admin);

        mockToken.transfer(address(user), 10 ether);

        staking = new ThriveStakingIERC20();
        staking.initialize(
            address(mockToken),
            yieldRate,
            minStakingAmount,
            address(accessControl),
            ADMIN_ROLE
        );
    }

    function testInitialize() public view {
        assertEq(staking.yieldRate(), yieldRate);
        assertEq(staking.minStakingAmount(), minStakingAmount);
        assertEq(staking.token(), address(mockToken));
    }

    function testStakeRevertsIfNativeSent() public {
        vm.prank(user);
        mockToken.transfer(user, 10 ether);
        mockToken.approve(user, 10 ether);

        vm.expectRevert(
            "ThriveProtocol: native should not be sent for ERC20 staking"
        );
        staking.stake{value: 1 ether}(minStakingAmount);
    }

    function testStakeRevertsForBelowMin() public {
        vm.prank(user);
        mockToken.approve(address(staking), 0.5 ether);

        vm.prank(user);
        vm.expectRevert("ThriveProtocol: below minimum stake");
        staking.stake(0.5 ether);
    }

    function testStakeSuccess() public {
        vm.prank(user);
        mockToken.approve(address(staking), minStakingAmount);

        vm.prank(user);
        staking.stake(minStakingAmount);
        (uint256 amount, uint256 stakingTime, uint256 lastYieldTime) =
            staking.stakers(user);

        assertEq(amount, minStakingAmount);
        assertGt(stakingTime, 0);
        assertGt(lastYieldTime, 0);
    }

    function testGetStakedAmount() public {
        vm.prank(user);
        mockToken.approve(address(staking), 2 ether);

        vm.prank(user);
        staking.stake(2 ether);

        uint256 staked = staking.getStakedAmount(user);
        assertEq(staked, 2 ether);
    }

    function testCalculateYield() public {
        vm.prank(user);
        mockToken.approve(address(staking), minStakingAmount);

        vm.prank(user);
        staking.stake(minStakingAmount);
        uint256 startTime = block.timestamp;

        vm.warp(startTime + 86400);
        uint256 yieldCalculated = staking.calculateYield(user);
        uint256 expected = (minStakingAmount * yieldRate * 86400) / 1e18;

        assertEq(yieldCalculated, expected);
    }

    function testClaimYieldRevertsIfNoStake() public {
        vm.prank(user);
        vm.expectRevert("ThriveProtocol: no staked tokens");
        staking.claimYield();
    }

    function testClaimYieldRevertsIfNoYield() public {
        vm.prank(user);
        mockToken.approve(address(staking), 10 ether);

        vm.prank(user);
        staking.stake(10 ether);

        vm.prank(user);
        vm.expectRevert("ThriveProtocol: no yield to claim");
        staking.claimYield();
    }

    function testClaimYieldSuccess() public {
        vm.prank(user);
        mockToken.approve(address(staking), 10 ether);

        vm.prank(user);
        staking.stake(10 ether);
        uint256 startTime = block.timestamp;

        vm.warp(startTime + 86400);
        uint256 yieldCalculated = staking.calculateYield(user);
        uint256 balanceBefore = mockToken.balanceOf(user);

        vm.prank(user);
        staking.claimYield();
        uint256 yieldAfter = staking.calculateYield(user);
        uint256 balanceAfter = mockToken.balanceOf(user);

        assertEq(yieldAfter, 0);
        assertEq(balanceAfter, balanceBefore + yieldCalculated);
    }

    function testGetWithdrawalTimestampRevertsForNoStake() public {
        vm.prank(user);
        vm.expectRevert("ThriveProtocol: no staked tokens");
        staking.getWithdrawalTimestamp(user);
    }

    function testGetWithdrawalTimestampReturnsCorrectTimestamp() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        mockToken.approve(address(staking), 10 ether);

        uint256 startTime = block.timestamp;
        vm.prank(user);
        staking.stake(minStakingAmount);

        uint256 withdrawalTimestamp = staking.getWithdrawalTimestamp(user);
        assertEq(withdrawalTimestamp, startTime + 30 days);
    }

    function testWithdrawRevertsBeforeLockup() public {
        vm.prank(user);
        mockToken.approve(address(staking), 10 ether);

        vm.prank(user);
        staking.stake(10 ether);

        vm.prank(user);
        vm.expectRevert("ThriveProtocol: 30-day lockup");
        staking.withdraw();
    }

    function testWithdrawSuccess() public {
        vm.prank(user);
        mockToken.transfer(address(staking), 10 ether);
        mockToken.approve(address(staking), 10 ether);
        staking.stake(minStakingAmount);
        uint256 startTime = block.timestamp;

        vm.warp(startTime + 31 days);
        staking.withdraw();
        (uint256 amount,,) = staking.stakers(user);

        assertEq(amount, 0);
    }

    function testAdminFunctions() public {
        uint256 newYield = 200;
        vm.prank(admin);
        staking.setYieldRate(newYield);

        assertEq(staking.yieldRate(), newYield);

        uint256 newMin = 2 ether;
        vm.prank(admin);
        staking.setMinStakingAmount(newMin);

        assertEq(staking.minStakingAmount(), newMin);
    }

    function testNonAdminCannotCallAdminFunctions() public {
        vm.prank(user);
        vm.expectRevert();
        staking.setYieldRate(300);

        vm.prank(user);
        vm.expectRevert();
        staking.setMinStakingAmount(3 ether);
    }

    function testStakeRevertsIfPendingYieldExists() public {
        vm.prank(user);
        mockToken.approve(address(staking), minStakingAmount);
        mockToken.approve(user, minStakingAmount);

        vm.prank(user);
        staking.stake(minStakingAmount);

        uint256 startTime = block.timestamp;
        vm.warp(startTime + 1000);

        vm.prank(user);
        mockToken.approve(address(staking), minStakingAmount);
        mockToken.approve(user, minStakingAmount);

        vm.prank(user);
        vm.expectRevert(
            "ThriveProtocol: claim yield first and retry stake again"
        );
        staking.stake(minStakingAmount);
    }

    function testSetAccessControlEnumerableRevertsForNonOwnerERC20() public {
        vm.prank(user);
        vm.expectRevert();
        staking.setAccessControlEnumerable(address(0), bytes32("NEW_ROLE"));
    }

    function testSetAccessControlEnumerableSuccessERC20() public {
        ThriveProtocolAccessControl newAccessControlImpl =
            new ThriveProtocolAccessControl();
        bytes memory data = abi.encodeCall(newAccessControlImpl.initialize, ());
        address newProxy =
            address(new ERC1967Proxy(address(newAccessControlImpl), data));
        bytes32 newAdminRole = keccak256("NEW_ROLE");

        staking.setAccessControlEnumerable(newProxy, newAdminRole);

        assertEq(staking.adminRole(), newAdminRole);
        assertEq(address(staking.accessControlEnumerable()), newProxy);
    }
}
