// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveStakingNative} from "../src/ThriveStakingNative.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";

/// @dev Test suite for native token staking logic
contract ThriveStakingNativeTest is Test {
    ThriveStakingNative staking;
    ThriveProtocolAccessControl public accessControl;
    address admin = address(0xABCD);
    address user = address(0xBEEF);
    uint256 yieldRate = 38_580_246_913; // Per-second rate for 10% monthly yield (0.1 * 1e18 / 2,592,000)
    uint256 minStakingAmount = 1 ether;
    uint256 EPOCH_DURATION = 30 days;
    uint256 HALF_EPOCH_DURATION = 15 days;
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
            yieldRate,
            minStakingAmount,
            EPOCH_DURATION,
            HALF_EPOCH_DURATION,
            address(accessControl),
            ADMIN_ROLE
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

        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

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

    function testCalculateYield_FirstHalfStake_SingleEpoch() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        (, uint256 firstHalfTimestamp,,,) = staking.stakers(user);

        uint256 epochEnd = staking.epochStart() + EPOCH_DURATION;
        vm.warp(epochEnd + 1);

        uint256 timeStaked = epochEnd - firstHalfTimestamp;
        uint256 expectedYield =
            (minStakingAmount * yieldRate * timeStaked) / 1e18;

        (uint256 claimableYield, uint256 ongoingYield) =
            staking.calculateYield(user);
        assertEq(
            claimableYield,
            expectedYield,
            "Claimable yield should match expected"
        );
        assertGt(ongoingYield, 0, "ongoing yield should be calculated");
    }

    function testCalculateYield_SecondHalfStake_SingleEpoch() public {
        vm.deal(user, 10 ether);
        vm.warp(staking.epochStart() + HALF_EPOCH_DURATION + 1);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        (,,, uint256 secondHalfTimestamp,) = staking.stakers(user);

        uint256 epochEnd = staking.epochStart() + EPOCH_DURATION;
        vm.warp(epochEnd + 1);

        uint256 timeStaked = epochEnd - secondHalfTimestamp;
        uint256 expectedYield =
            (minStakingAmount * yieldRate * timeStaked) / (2 * 1e18);

        (uint256 claimableYield,) = staking.calculateYield(user);
        assertEq(
            claimableYield,
            expectedYield,
            "Claimable yield should match expected"
        );
    }

    function testCalculateYield_MultipleEpochs() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        (, uint256 firstHalfTimestamp,,,) = staking.stakers(user);

        uint256 epoch3Start = staking.epochStart() + (3 * EPOCH_DURATION);
        vm.warp(epoch3Start);

        uint256 firstEpochTime =
            staking.epochStart() + EPOCH_DURATION - firstHalfTimestamp;
        uint256 firstEpochYield =
            (minStakingAmount * yieldRate * firstEpochTime) / 1e18;
        uint256 fullEpochYield =
            (minStakingAmount * yieldRate * EPOCH_DURATION) / 1e18;
        uint256 expectedYield = firstEpochYield + (2 * fullEpochYield);

        (uint256 claimableYield, uint256 ongoingYield) =
            staking.calculateYield(user);
        assertEq(
            claimableYield, expectedYield, "Claimable yield should be 0.3 ETH"
        );
        assertEq(ongoingYield, 0, "No ongoing yield at epoch start");
    }

    function testClaimYieldNoStake() public {
        vm.prank(user);
        vm.expectRevert("ThriveProtocol: no staked tokens");
        staking.claimYield();
    }

    function testClaimYieldInsufficientFunds() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        vm.warp(staking.epochStart() + EPOCH_DURATION + 1);
        vm.deal(address(staking), 0);

        vm.prank(user);
        vm.expectRevert("Native yield transfer failed");
        staking.claimYield();
    }

    function testClaimYieldSuccess() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        uint256 epochEnd = staking.epochStart() + EPOCH_DURATION;
        vm.warp(epochEnd + 1);
        vm.deal(address(staking), 1_000 ether);

        (uint256 expectedYield,) = staking.calculateYield(user);
        uint256 balanceBefore = user.balance;

        vm.prank(user);
        staking.claimYield();

        assertEq(
            user.balance,
            balanceBefore + expectedYield,
            "Balance should increase by yield"
        );
        assertEq(
            staking.claimableYield(user), 0, "Claimable yield should reset"
        );
        (uint256 firstHalf,, uint256 secondHalf,, uint256 epoch) =
            staking.stakers(user);
        assertEq(firstHalf, minStakingAmount, "Stake should persist");
        assertEq(secondHalf, 0, "Second half should be 0");
        assertEq(epoch, 1, "Epoch should update to current");
    }

    function testYieldAcrossMultipleEpochs() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        uint256 epoch3Start = staking.epochStart() + (3 * EPOCH_DURATION);
        vm.warp(epoch3Start);
        vm.deal(address(staking), 1_000 ether);

        (uint256 yieldBefore,) = staking.calculateYield(user);
        assertGt(
            yieldBefore, 0.25 ether, "Yield should be ~=0.3 ETH after 3 epochs"
        );

        vm.prank(user);
        staking.claimYield();

        assertEq(
            staking.getStakedAmount(user), minStakingAmount, "Stake persists"
        );
        (uint256 yieldAfter,) = staking.calculateYield(user);
        assertEq(yieldAfter, 0, "Claimable yield resets after claim");
    }

    function testYieldWithMixedStakes() public {
        vm.deal(user, 10 ether);

        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        vm.warp(staking.epochStart() + HALF_EPOCH_DURATION);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        vm.warp(staking.epochStart() + EPOCH_DURATION + 1);
        (uint256 claimableYield,) = staking.calculateYield(user);

        uint256 firstYield =
            (minStakingAmount * yieldRate * EPOCH_DURATION) / 1e18;
        uint256 secondYield =
            (minStakingAmount * yieldRate * HALF_EPOCH_DURATION) / (2 * 1e18);
        uint256 expectedYield = firstYield + secondYield;

        assertEq(
            claimableYield,
            expectedYield,
            "Yield should match mixed stake calculation"
        );
    }

    function testWithdrawBeforeEpochEnds() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        vm.warp(block.timestamp + 10 days);
        uint256 balanceBefore = user.balance;

        vm.prank(user);
        staking.withdraw();

        assertEq(
            user.balance,
            balanceBefore + minStakingAmount,
            "Only principal returned"
        );
        assertEq(staking.getStakedAmount(user), 0, "Stake should be 0");
        assertEq(staking.claimableYield(user), 0, "Claimable yield remains 0");
    }

    function testWithdrawNoContractFunds() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        vm.warp(staking.epochStart() + EPOCH_DURATION + 1);
        vm.deal(address(staking), 0);
        vm.prank(user);
        vm.expectRevert("Native staked amount transfer failed");
        staking.withdraw();
    }

    function testWithdrawMultipleEpochs() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        uint256 epoch3Start = staking.epochStart() + (3 * EPOCH_DURATION);
        vm.warp(epoch3Start);
        vm.deal(address(staking), 1_000 ether);

        (uint256 expectedYield,) = staking.calculateYield(user);
        assertGt(expectedYield, 0.25 ether, "Yield should be ~=0.3 ETH");

        uint256 balanceBefore = user.balance;
        vm.prank(user);
        staking.withdraw();

        assertEq(
            user.balance,
            balanceBefore + minStakingAmount + expectedYield,
            "Full withdrawal"
        );
        assertEq(staking.getStakedAmount(user), 0, "Stake should be 0");
        assertEq(staking.claimableYield(user), 0, "Claimable yield resets");
    }

    function testWithdrawMidEpochWithPartialYield() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        vm.warp(staking.epochStart() + HALF_EPOCH_DURATION);
        vm.deal(address(staking), 1_000 ether);

        vm.warp(staking.epochStart() + EPOCH_DURATION);
        (uint256 partialYield,) = staking.calculateYield(user);
        assertGt(partialYield, 0, "Partial yield should accumulate");

        uint256 balanceBefore = user.balance;
        vm.prank(user);
        staking.withdraw();

        assertEq(
            user.balance,
            balanceBefore + minStakingAmount + partialYield,
            "Should withdraw principal plus partial yield"
        );
        assertEq(staking.getStakedAmount(user), 0, "Stake should be 0");
    }

    function testWithdrawWithNoStake() public {
        vm.prank(user);
        vm.expectRevert("ThriveProtocol: no staked tokens");
        staking.withdraw();
    }

    function testWithdrawInsufficientContractBalance() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        vm.warp(staking.epochStart() + EPOCH_DURATION + 1);
        vm.deal(address(staking), 0);

        vm.prank(user);
        vm.expectRevert("Native staked amount transfer failed");
        staking.withdraw();
    }

    function testAdminFunctions() public {
        uint256 newYieldRate = 19_290_123_456;
        vm.prank(admin);
        staking.setYieldRate(newYieldRate);
        assertEq(staking.yieldRate(), newYieldRate, "Yield rate not updated");

        uint256 newMin = 2 ether;
        vm.prank(admin);
        staking.setMinStakingAmount(newMin);
        assertEq(
            staking.minStakingAmount(), newMin, "Min staking amount not updated"
        );
    }

    function testNonAdminCannotCallAdminFunctions() public {
        vm.prank(user);
        vm.expectRevert();
        staking.setYieldRate(300);

        vm.prank(user);
        vm.expectRevert();
        staking.setMinStakingAmount(3 ether);
    }

    function testStakeAnytime() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        vm.warp(staking.epochStart() + EPOCH_DURATION + 1);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        assertEq(
            staking.getStakedAmount(user),
            2 ether,
            "Total stake should be 2 ETH"
        );
    }

    function testStakeYieldSecondHalf() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        vm.warp(staking.epochStart() + EPOCH_DURATION + HALF_EPOCH_DURATION + 1);
        vm.deal(address(staking), 1 ether);
        vm.prank(user);
        staking.stakeYield();
        (,, uint256 secondHalf,,) = staking.stakers(user);
        assertGt(secondHalf, 0);
    }

    function testStakeAtEpochStart() public {
        vm.deal(user, 10 ether);
        vm.warp(staking.epochStart());
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        (uint256 firstHalf, uint256 firstHalfTimestamp,,,) =
            staking.stakers(user);
        assertEq(firstHalf, minStakingAmount, "Stake should be in first half");
        assertEq(
            firstHalfTimestamp,
            staking.epochStart(),
            "Timestamp should match epoch start"
        );
    }

    function testStakeJustBeforeEpochEnd() public {
        vm.deal(user, 10 ether);
        vm.warp(staking.epochStart() + EPOCH_DURATION - 1);

        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        (,, uint256 secondHalf, uint256 secondHalfTimestamp,) =
            staking.stakers(user);

        assertEq(secondHalf, minStakingAmount, "Stake should be in second half");
        assertEq(
            secondHalfTimestamp,
            block.timestamp,
            "Timestamp should match stake time"
        );
    }

    function testStakeAtHalfEpochBoundary() public {
        vm.deal(user, 10 ether);
        vm.warp(staking.epochStart() + HALF_EPOCH_DURATION);

        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        (,, uint256 secondHalf,,) = staking.stakers(user);

        assertEq(secondHalf, minStakingAmount);
    }

    function testStakeWithPendingYield() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        vm.warp(staking.epochStart() + (2 * EPOCH_DURATION));
        (uint256 pendingYield,) = staking.calculateYield(user);
        assertGt(pendingYield, 0, "Should have pending yield");

        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        assertEq(
            staking.getStakedAmount(user),
            2 ether,
            "Total stake should be 2 ETH"
        );
        (uint256 firstHalf,, uint256 secondHalf,,) = staking.stakers(user);

        assertEq(firstHalf, 2 ether, "First half should accumulate both stakes");
        assertEq(secondHalf, 0, "Second half should be 0");
    }

    function testClaimableYieldStorageBeforeInteraction() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);

        vm.warp(staking.epochStart() + (3 * EPOCH_DURATION));
        assertEq(
            staking.claimableYield(user),
            0,
            "Claimable yield in storage is 0 before interaction"
        );
        (uint256 totalClaimableYield,) = staking.calculateYield(user);
        assertGt(
            totalClaimableYield,
            0.25 ether,
            "Total claimable yield shows correctly"
        );
    }

    function testGetEpochEndTimestamp() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        uint256 epochEnd = staking.getEpochEndTimestamp(user);

        assertEq(
            epochEnd,
            staking.epochStart() + EPOCH_DURATION,
            "Epoch end timestamp should match expected"
        );
    }

    function testSetYieldRateToZero() public {
        vm.prank(admin);
        staking.setYieldRate(0);

        assertEq(staking.yieldRate(), 0, "Yield rate should be 0");

        vm.deal(user, 10 ether);
        vm.prank(user);
        staking.stake{value: minStakingAmount}(minStakingAmount);
        vm.warp(staking.epochStart() + EPOCH_DURATION + 1);
        (uint256 claimableYield,) = staking.calculateYield(user);

        assertEq(claimableYield, 0, "Yield should be 0 with zero rate");
    }

    function testSetAccessControlEnumerableSuccess() public {
        address newAccessControl = address(0x1234);
        bytes32 newRole = keccak256("NEW_ROLE");
        vm.prank(address(this));
        staking.setAccessControlEnumerable(newAccessControl, newRole);

        assertEq(address(staking.accessControlEnumerable()), newAccessControl);
        assertEq(staking.adminRole(), newRole);
    }

    function testSetAccessControlEnumerableNonOwner() public {
        address newAccessControl = address(0x1234);
        bytes32 newRole = keccak256("NEW_ROLE");

        vm.prank(admin);
        vm.expectRevert();
        staking.setAccessControlEnumerable(newAccessControl, newRole);
    }
}
