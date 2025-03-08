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
    uint256 yieldRate = 38580246913; // Per-second rate for 10% monthly yield
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
        (
            uint256 firstHalf,
            uint256 firstHalfTimestamp,
            uint256 secondHalf,
            uint256 secondHalfTimestamp,
            uint256 epoch
        ) = staking.stakers(user);
        uint256 currentEpoch = staking.currentEpoch();

        assertEq(firstHalf, minStakingAmount);
        assertGt(firstHalfTimestamp, 0);
        assertEq(secondHalf, 0);
        assertEq(secondHalfTimestamp, 0);
        assertEq(epoch, currentEpoch);
    }

    function testMultipleStakesInEpoch() public {
        vm.deal(user, 10 ether);

        // First stake
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        // Second stake in the same epoch
        vm.warp(block.timestamp + 5 days);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        (uint256 firstHalf,, uint256 secondHalf,,) = staking.stakers(user);
        assertEq(firstHalf, 2 ether, "First half should accumulate both stakes");
        assertEq(secondHalf, 0, "Second half should be empty");

        uint256 totalStaked = staking.getStakedAmount(user);
        assertEq(totalStaked, 2 ether, "Total staked should be 2 ether");
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
        (
            uint256 firstHalfAmount,
            uint256 firstHalfTimestamp,
            ,
            ,
            uint256 stakeEpoch
        ) = staking.stakers(user);

        uint256 epochStart = staking.epochStart() + (stakeEpoch * 30 days);
        uint256 epochEnd = epochStart + 30 days;
        vm.warp(epochEnd + 1); // Warp to after epoch end

        uint256 effectiveTime = epochEnd; // Since block.timestamp > epochEnd, effectiveTime = epochEnd
        uint256 timeStaked = effectiveTime - firstHalfTimestamp;
        uint256 expectedYield =
            (firstHalfAmount * yieldRate * timeStaked) / 1e18;

        (uint256 claimableYield, uint256 ongoingYield) =
            staking.calculateYield(user);
        assertEq(claimableYield, expectedYield);
        assertEq(ongoingYield, 0); // Epoch has ended, so no ongoing yield
    }

    function testCalculateYield_SecondHalfStake() public {
        vm.deal(user, 10 ether);
        uint256 currentEpoch = staking.currentEpoch();
        uint256 epochPhaseStart =
            staking.epochStart() + (currentEpoch * 30 days);
        vm.warp(epochPhaseStart + 16 days); // Warp to second half of the epoch

        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        (
            ,
            ,
            uint256 secondHalfAmount,
            uint256 secondHalfTimestamp,
            uint256 stakeEpoch
        ) = staking.stakers(user);

        uint256 epochEnd = staking.epochStart() + ((stakeEpoch + 1) * 30 days);
        vm.warp(epochEnd + 1); // Warp to after epoch end

        uint256 effectiveTime = epochEnd;
        uint256 timeStaked = effectiveTime - secondHalfTimestamp;
        uint256 expectedYield =
            (secondHalfAmount * yieldRate * timeStaked) / (2 * 1e18);

        (uint256 claimableYield, uint256 ongoingYield) =
            staking.calculateYield(user);
        assertEq(claimableYield, expectedYield);
        assertEq(ongoingYield, 0);
    }

    function testClaimYieldRevertsIfNoStake() public {
        vm.prank(user);
        vm.expectRevert("ThriveProtocol: no staked tokens");
        staking.claimYield();
    }

    function testClaimYieldFailsWithInsufficientFunds() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount); // e.g., 1 ether

        uint256 epochEnd = staking.epochStart() + 30 days;
        vm.warp(epochEnd + 1);

        vm.deal(address(staking), 0);
        assertEq(address(staking).balance, 0, "Contract balance should be zero");

        vm.prank(user);
        vm.expectRevert("Native yield transfer failed");
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
        (,,,, uint256 stakeEpoch) = staking.stakers(user);
        uint256 epochEnd = staking.epochStart() + ((stakeEpoch + 1) * 30 days);

        vm.warp(epochEnd + 1);
        vm.deal(address(staking), 1_000 ether);

        (uint256 claimableYield,) = staking.calculateYield(user);
        assertGt(claimableYield, 0);

        uint256 balanceBefore = address(user).balance;

        vm.prank(user);
        staking.claimYield();

        (uint256 yieldAfter,) = staking.calculateYield(user);
        assertEq(yieldAfter, 0); // Claimable yield should be reset

        (uint256 firstHalf,, uint256 secondHalf,, uint256 newEpoch) =
            staking.stakers(user);
        uint256 totalStaked = firstHalf + secondHalf;
        uint256 balanceAfter = address(user).balance;

        assertEq(totalStaked, minStakingAmount);
        assertEq(firstHalf, minStakingAmount);
        assertEq(secondHalf, 0);
        assertEq(newEpoch, staking.currentEpoch());
        assertEq(balanceAfter, balanceBefore + claimableYield);
    }

    function testYieldAcrossMultipleEpochs() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        (,,,, uint256 stakeEpoch) = staking.stakers(user);

        uint256 epoch1End = staking.epochStart() + ((stakeEpoch + 1) * 30 days);
        vm.warp(epoch1End + 1);
        vm.deal(address(staking), 1_000 ether);

        (uint256 yield1,) = staking.calculateYield(user);
        vm.prank(user);
        staking.claimYield();

        uint256 epoch2End = epoch1End + 30 days;
        vm.warp(epoch2End + 1);
        (uint256 yield2,) = staking.calculateYield(user);

        assertGt(yield1, 0);
        assertGt(yield2, 0);
        assertEq(staking.getStakedAmount(user), minStakingAmount); // Stake persists
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

    function testWithdrawBeforeEpochEnds() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        vm.warp(block.timestamp + 10 days);
        uint256 balanceBefore = address(user).balance;

        vm.prank(user);
        staking.withdraw();

        uint256 balanceAfter = address(user).balance;
        assertEq(balanceAfter, balanceBefore + minStakingAmount);
        assertEq(staking.getStakedAmount(user), 0);
    }

    function testWithdrawForfeitsYieldBeforeEpochEnd() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        vm.prank(user);
        staking.withdraw();
        (uint256 firstHalf,, uint256 secondHalf,, uint256 epoch) =
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
        (
            uint256 firstHalfAmount,
            uint256 firstHalfTimestamp,
            ,
            ,
            uint256 stakeEpoch
        ) = staking.stakers(user);

        uint256 epochEnd = staking.epochStart() + ((stakeEpoch + 1) * 30 days);
        vm.warp(epochEnd + 1);

        uint256 balanceBefore = address(user).balance;
        uint256 stakedAmount = staking.getStakedAmount(user);

        uint256 effectiveTime = epochEnd;
        uint256 timeStaked = effectiveTime - firstHalfTimestamp;
        uint256 expectedYield =
            (firstHalfAmount * yieldRate * timeStaked) / 1e18;

        vm.prank(user);
        staking.withdraw();

        (,,,, uint256 epochAfter) = staking.stakers(user);
        assertEq(epochAfter, 0);

        uint256 balanceAfter = address(user).balance;
        assertEq(balanceAfter, balanceBefore + stakedAmount + expectedYield);
    }

    function testAdminFunctions() public {
        uint256 newYieldRate = 19_290_123_456;
        vm.prank(admin);
        staking.setYieldRate(newYieldRate);
        assertEq(staking.yieldRate(), newYieldRate, "Yield rate not updated");

        uint256 newMin = 2 ether;
        vm.prank(admin);
        staking.setMinStakingAmount(newMin);
        assertEq(staking.minStakingAmount(), newMin);
    }

    function testYieldRateChangeMidEpoch() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        vm.warp(block.timestamp + 15 days);
        vm.prank(admin);
        staking.setYieldRate(yieldRate * 2);

        uint256 epochEnd = staking.epochStart() + 30 days;
        vm.warp(epochEnd + 1);
        vm.deal(address(staking), 1_000 ether);

        (uint256 yield,) = staking.calculateYield(user);
        vm.prank(user);
        staking.claimYield();

        assertGt(yield, 0);
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

    function testStakeAtEpochBoundary() public {
        vm.deal(user, 10 ether);
        uint256 epochEnd = staking.epochStart() + 30 days;
        vm.warp(epochEnd);

        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        vm.warp(epochEnd + 30 days + 1);
        vm.deal(address(staking), 1_000 ether);

        (uint256 yield,) = staking.calculateYield(user);
        assertGt(yield, 0);
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
