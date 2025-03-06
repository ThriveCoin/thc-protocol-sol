// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveStakingIERC20} from "../src/ThriveStakingIERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";
import {MockERC20} from "test/mock/MockERC20.sol";

/// @dev Test suite for ERC20 token staking logic.
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

        ThriveProtocolAccessControl accessControlImpl = new ThriveProtocolAccessControl();
        bytes memory accessControlData = abi.encodeCall(accessControlImpl.initialize, ());
        address accessControlProxy = address(new ERC1967Proxy(address(accessControlImpl), accessControlData));
        accessControl = ThriveProtocolAccessControl(accessControlProxy);
        accessControl.grantRole(ADMIN_ROLE, admin);

        mockToken.transfer(user, 10 ether);

        staking = new ThriveStakingIERC20();
        staking.initialize(address(mockToken), yieldRate, minStakingAmount, address(accessControl), ADMIN_ROLE);
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

        vm.expectRevert("ThriveProtocol: native should not be sent for ERC20 staking");
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
        (uint256 firstHalf, uint256 secondHalf, uint256 epoch) = staking.stakers(user);
        uint256 currentEpoch = staking.currentEpoch();

        assertEq(firstHalf, minStakingAmount);
        assertEq(secondHalf, 0);
        assertEq(epoch, currentEpoch);
    }

    function testGetStakedAmount() public {
        vm.prank(user);
        mockToken.approve(address(staking), 2 ether);

        vm.prank(user);
        staking.stake(2 ether);
        uint256 staked = staking.getStakedAmount(user);

        assertEq(staked, 2 ether);
    }

    function testCalculateYield_FirstHalfStake() public {
        vm.prank(user);
        mockToken.approve(address(staking), minStakingAmount);

        vm.prank(user);
        staking.stake(minStakingAmount);
        uint256 staked = minStakingAmount;

        uint256 currentEpoch = staking.currentEpoch();
        uint256 epochEnd = staking.epochStart() + ((currentEpoch + 1) * 30 days);
        vm.warp(epochEnd + 1);
        uint256 expectedYield = (staked * yieldRate) / 1e18;
        uint256 yieldCalculated = staking.calculateYield(user);

        assertEq(yieldCalculated, expectedYield);
    }

    function testCalculateYield_SecondHalfStake() public {
        uint256 currentEpoch = staking.currentEpoch();
        uint256 epochPhaseStart = staking.epochStart() + (currentEpoch * 30 days);
        vm.warp(epochPhaseStart + 16 days);
        vm.prank(user);
        mockToken.approve(address(staking), minStakingAmount);

        vm.prank(user);
        staking.stake(minStakingAmount);
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
        vm.prank(user);
        mockToken.approve(address(staking), 10 ether);

        vm.prank(user);
        staking.stake(10 ether);

        vm.prank(user);
        vm.expectRevert("ThriveProtocol: epoch not finished");
        staking.claimYield();
    }

    function testClaimYieldSuccess() public {
        vm.prank(user);
        mockToken.approve(address(staking), 10 ether);
        vm.prank(user);
        staking.stake(10 ether);
        uint256 initialEpoch = staking.currentEpoch();
        uint256 epochEnd = staking.epochStart() + ((initialEpoch + 1) * 30 days);
        vm.warp(epochEnd + 1);

        uint256 yieldCalculated = staking.calculateYield(user);
        uint256 balanceBefore = mockToken.balanceOf(user);

        vm.prank(user);
        staking.claimYield();

        uint256 yieldAfter = staking.calculateYield(user);
        assertEq(yieldAfter, 0);

        (uint256 firstHalf, uint256 secondHalf, uint256 newEpoch) = staking.stakers(user);
        uint256 totalStaked = firstHalf + secondHalf;
        uint256 balanceAfter = mockToken.balanceOf(user);

        assertEq(totalStaked, 10 ether);
        assertEq(newEpoch, staking.currentEpoch());
        assertEq(balanceAfter, balanceBefore + yieldCalculated);
    }

    function testGetEpochEndTimestampRevertsForNoStake() public {
        vm.prank(user);
        vm.expectRevert("ThriveProtocol: no staked tokens");
        staking.getEpochEndTimestamp(user);
    }

    function testGetEpochEndTimestampReturnsCorrectTimestamp() public {
        vm.prank(user);
        mockToken.approve(address(staking), 10 ether);
        uint256 currentEpoch = staking.currentEpoch();
        uint256 expectedEpochEnd = staking.epochStart() + ((currentEpoch + 1) * 30 days);

        vm.prank(user);
        staking.stake(minStakingAmount);
        uint256 epochEndTimestamp = staking.getEpochEndTimestamp(user);

        assertEq(epochEndTimestamp, expectedEpochEnd);
    }

    function testWithdrawForfeitsYieldBeforeEpochEnd() public {
        vm.prank(user);
        mockToken.approve(address(staking), 10 ether);

        vm.prank(user);
        staking.stake(10 ether);

        vm.prank(user);
        staking.withdraw();
        (uint256 firstHalf, uint256 secondHalf, uint256 epoch) = staking.stakers(user);

        assertEq(firstHalf, 0);
        assertEq(secondHalf, 0);
        assertEq(epoch, 0);
    }

    function testWithdrawSuccessWithYield() public {
        vm.prank(user);
        mockToken.transfer(user, 10 ether);
        mockToken.approve(address(staking), minStakingAmount);
        mockToken.transfer(address(staking), 10 ether);
        mockToken.approve(address(staking), 10 ether);

        staking.stake(minStakingAmount);
        uint256 initialEpoch = staking.currentEpoch();
        uint256 epochEnd = staking.epochStart() + ((initialEpoch + 1) * 30 days);
        vm.warp(epochEnd + 1);

        uint256 balanceBefore = mockToken.balanceOf(user);
        staking.withdraw();
        (uint256 firstHalf, uint256 secondHalf, uint256 epochAfter) = staking.stakers(user);

        assertEq(firstHalf, 0);
        assertEq(secondHalf, 0);
        assertEq(epochAfter, 0);

        uint256 balanceAfter = mockToken.balanceOf(user);
        // TODO: this need to be rechecked with rilind
        // uint256 nativeBalanceAfterYield = address(user).balance;
        // uint256 expectedYield = (minStakingAmount * yieldRate) / 1e18;

        assertEq(balanceAfter, balanceBefore);
        // assertEq(nativeBalanceAfterYield, expectedYield);
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
        vm.prank(user);
        staking.stake(minStakingAmount);
        uint256 initialEpoch = staking.currentEpoch();
        vm.warp(staking.epochStart() + ((initialEpoch + 1) * 30 days) + 1);
        vm.prank(user);
        mockToken.approve(address(staking), minStakingAmount);
        vm.prank(user);
        vm.expectRevert("ThriveProtocol: finalize previous epoch first");
        staking.stake(minStakingAmount);
    }

    function testSetAccessControlEnumerableRevertsForNonOwnerERC20() public {
        vm.prank(user);
        vm.expectRevert();
        staking.setAccessControlEnumerable(address(0), bytes32("NEW_ROLE"));
    }

    function testSetAccessControlEnumerableSuccessERC20() public {
        ThriveProtocolAccessControl newAccessControlImpl = new ThriveProtocolAccessControl();
        bytes memory data = abi.encodeCall(newAccessControlImpl.initialize, ());
        address newProxy = address(new ERC1967Proxy(address(newAccessControlImpl), data));
        bytes32 newAdminRole = keccak256("NEW_ROLE");

        staking.setAccessControlEnumerable(newProxy, newAdminRole);

        assertEq(staking.adminRole(), newAdminRole);
        assertEq(address(staking.accessControlEnumerable()), newProxy);
    }
}
