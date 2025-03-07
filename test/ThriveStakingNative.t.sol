// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveStakingNative} from "../src/ThriveStakingNative.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";

/// @dev Test suite for native token staking logic.
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
        (uint256 firstHalf, uint256 secondHalf, uint256 epoch) =
            staking.stakers(user);
        uint256 currentEpoch = staking.currentEpoch();

        assertEq(firstHalf, minStakingAmount);
        assertEq(secondHalf, 0);
        assertEq(epoch, currentEpoch);
    }

    function testGetStakedAmount() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: 1 ether}(1 ether);
        uint256 staked = staking.getStakedAmount(user);

        assertEq(staked, 1 ether);
    }

    function testCalculateYield_FirstHalfStake() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        uint256 staked = minStakingAmount; // full stake in first half

        uint256 currentEpoch = staking.currentEpoch();
        uint256 epochEnd = staking.epochStart() + ((currentEpoch + 1) * 30 days);
        vm.warp(epochEnd + 1);
        uint256 expectedYield = (staked * yieldRate) / 1e18;
        uint256 yieldCalculated = staking.calculateYield(user);

        assertEq(yieldCalculated, expectedYield);
    }

    function testCalculateYield_SecondHalfStake() public {
        vm.deal(user, 10 ether);
        uint256 currentEpoch = staking.currentEpoch();
        uint256 epochPhaseStart =
            staking.epochStart() + (currentEpoch * 30 days);
        vm.warp(epochPhaseStart + 16 days); // ensure we're in the second half (>15 days)

        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        uint256 staked = minStakingAmount;

        uint256 epochEnd = staking.epochStart() + ((currentEpoch + 1) * 30 days);
        vm.warp(epochEnd + 1);

        uint256 expectedYield = (staked * yieldRate) / (2 * 1e18);
        uint256 yieldCalculated = staking.calculateYield(user);
        assertEq(yieldCalculated, expectedYield);
    }

    function testClaimYieldRevertsIfNoStake() public {
        vm.prank(user);
        vm.expectRevert("ThriveProtocol: no staked tokens");
        staking.claimYield();
    }

    function testClaimYieldRevertsIfEpochNotFinished() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        vm.prank(user);
        vm.expectRevert("ThriveProtocol: epoch not finished");
        staking.claimYield();
    }

    function testClaimYieldSuccess() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        uint256 initialEpoch = staking.currentEpoch();

        uint256 epochEnd = staking.epochStart() + ((initialEpoch + 1) * 30 days);
        vm.warp(epochEnd + 1);

        uint256 yieldCalculated = staking.calculateYield(user);
        assertGt(yieldCalculated, 0);

        uint256 balanceBefore = address(user).balance;

        vm.prank(user);
        staking.claimYield();

        uint256 yieldAfter = staking.calculateYield(user);
        assertEq(yieldAfter, 0);

        (uint256 firstHalf, uint256 secondHalf, uint256 newEpoch) =
            staking.stakers(user);
        uint256 totalStaked = firstHalf + secondHalf;
        uint256 balanceAfter = address(user).balance;

        assertEq(totalStaked, minStakingAmount);
        assertEq(newEpoch, staking.currentEpoch());
        assertEq(balanceAfter, balanceBefore + yieldCalculated);
    }

    function testGetEpochEndTimestampRevertsForNoStake() public {
        vm.prank(user);
        vm.expectRevert("ThriveProtocol: no staked tokens");
        staking.getEpochEndTimestamp(user);
    }

    function testGetEpochEndTimestampReturnsCorrectTimestamp() public {
        vm.deal(user, 10 ether);
        uint256 currentEpoch = staking.currentEpoch();
        uint256 expectedEpochEnd =
            staking.epochStart() + ((currentEpoch + 1) * 30 days);

        vm.prank(user);
        staking.stake{value: 1 ether}(1 ether);
        uint256 epochEndTimestamp = staking.getEpochEndTimestamp(user);

        assertEq(epochEndTimestamp, expectedEpochEnd);
    }

    function testWithdrawForfeitsYieldBeforeEpochEnd() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        vm.prank(user);
        staking.withdraw();
        (uint256 firstHalf, uint256 secondHalf, uint256 epoch) =
            staking.stakers(user);

        assertEq(firstHalf, 0);
        assertEq(secondHalf, 0);
        assertEq(epoch, 0);
    }

    function testWithdrawSuccessWithYield() public {
        vm.deal(address(staking), 1_000 ether);
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        uint256 initialEpoch = staking.currentEpoch();
        uint256 epochEnd = staking.epochStart() + ((initialEpoch + 1) * 30 days);
        vm.warp(epochEnd + 1);

        uint256 balanceBefore = address(user).balance;
        uint256 stakedAmount = staking.getStakedAmount(user);
        vm.prank(user);
        staking.withdraw();
        (uint256 firstHalf, uint256 secondHalf, uint256 epochAfter) =
            staking.stakers(user);

        assertEq(firstHalf, 0);
        assertEq(secondHalf, 0);
        assertEq(epochAfter, 0);

        uint256 expectedYield = (minStakingAmount * yieldRate) / 1e18;
        uint256 balanceAfter = address(user).balance;

        assertEq(balanceAfter, balanceBefore + stakedAmount + expectedYield);
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
        uint256 initialEpoch = staking.currentEpoch();
        vm.warp(staking.epochStart() + ((initialEpoch + 1) * 30 days) + 1);
        vm.deal(user, 10 ether);

        vm.prank(user);
        vm.expectRevert("ThriveProtocol: finalize previous epoch first");
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
