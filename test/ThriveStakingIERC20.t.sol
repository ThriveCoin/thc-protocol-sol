// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveStakingIERC20} from "../src/ThriveStakingIERC20.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";
import {MockERC20} from "test/mock/MockERC20.sol";

/// @dev Test suite for ERC20 token staking logic with automatic rollover.
contract ThriveStakingERC20Test is Test {
    ThriveStakingIERC20 staking;
    MockERC20 public mockToken;
    ThriveProtocolAccessControl public accessControl;
    address admin = address(0xABCD);
    address user = address(0xBEEF);
    uint256 yieldRate = 38_580_246_913; // Per-second rate for 10% monthly yield (0.1 * 1e18 / 2,592,000)
    uint256 minStakingAmount = 1 ether;
    uint256 EPOCH_DURATION = 30 days;
    uint256 HALF_EPOCH_DURATION = 15 days;
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

        mockToken.transfer(user, 10 ether);

        staking = new ThriveStakingIERC20();
        staking.initialize(
            address(mockToken),
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
        assertEq(staking.token(), address(mockToken));
    }

    function testStakeRevertsIfNativeSent() public {
        vm.prank(user);
        mockToken.approve(address(staking), minStakingAmount);
        vm.prank(user);
        vm.deal(user, 10 ether);
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

    function testGetStakedAmount() public {
        vm.prank(user);
        mockToken.approve(address(staking), 2 ether);
        vm.prank(user);
        staking.stake(2 ether);
        uint256 staked = staking.getStakedAmount(user);

        assertEq(staked, 2 ether);
    }

    function testCalculateYield_FirstHalfStake_SingleEpoch() public {
        vm.prank(user);
        mockToken.approve(address(staking), minStakingAmount);
        vm.prank(user);
        staking.stake(minStakingAmount);
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
    }

    function testCalculateYield_SecondHalfStake_SingleEpoch() public {
        vm.warp(staking.epochStart() + HALF_EPOCH_DURATION + 1); // Second half
        vm.prank(user);
        mockToken.approve(address(staking), minStakingAmount);
        vm.prank(user);
        staking.stake(minStakingAmount);
        (,,, uint256 secondHalfTimestamp,) = staking.stakers(user);

        uint256 epochEnd = staking.epochStart() + EPOCH_DURATION;
        vm.warp(epochEnd + 1);

        uint256 timeStaked = epochEnd - secondHalfTimestamp;
        uint256 expectedYield =
            (minStakingAmount * yieldRate * timeStaked) / (2 * 1e18);

        (uint256 claimableYield, uint256 ongoingYield) =
            staking.calculateYield(user);
        assertEq(
            claimableYield,
            expectedYield,
            "Claimable yield should match expected"
        );
    }

    function testCalculateYield_MultipleEpochs() public {
        vm.prank(user);
        mockToken.approve(address(staking), minStakingAmount);
        vm.prank(user);
        staking.stake(minStakingAmount);
        (, uint256 firstHalfTimestamp,,,) = staking.stakers(user);

        // Warp to start of Epoch 3 (90 days)
        uint256 epoch3Start = staking.epochStart() + (3 * EPOCH_DURATION);
        vm.warp(epoch3Start);

        uint256 firstEpochTime =
            staking.epochStart() + EPOCH_DURATION - firstHalfTimestamp;
        uint256 firstEpochYield =
            (minStakingAmount * yieldRate * firstEpochTime) / 1e18;
        uint256 fullEpochYield =
            (minStakingAmount * yieldRate * EPOCH_DURATION) / 1e18;
        uint256 expectedYield = firstEpochYield + (2 * fullEpochYield); // 0.3 ETH total

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
        vm.prank(user);
        mockToken.approve(address(staking), minStakingAmount);
        vm.prank(user);
        staking.stake(minStakingAmount);

        vm.warp(staking.epochStart() + EPOCH_DURATION + 1);
        vm.deal(address(staking), 0); // No native funds for yield

        vm.prank(user);
        vm.expectRevert("Native yield transfer failed");
        staking.claimYield();
    }

    function testClaimYieldSuccess() public {
        vm.prank(user);
        mockToken.approve(address(staking), minStakingAmount);
        vm.prank(user);
        staking.stake(minStakingAmount);

        uint256 epochEnd = staking.epochStart() + EPOCH_DURATION;
        vm.warp(epochEnd + 1);
        vm.deal(address(staking), 10 ether);

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
        vm.prank(user);
        mockToken.approve(address(staking), minStakingAmount);
        vm.prank(user);
        staking.stake(minStakingAmount);

        // Warp to Epoch 3 start
        uint256 epoch3Start = staking.epochStart() + (3 * EPOCH_DURATION);
        vm.warp(epoch3Start);
        vm.deal(address(staking), 10 ether);

        (uint256 yieldBefore,) = staking.calculateYield(user);
        assertGt(
            yieldBefore, 0.29 ether, "Yield should be ~=0.3 ETH after 3 epochs"
        );

        vm.prank(user);
        staking.claimYield();

        assertEq(
            staking.getStakedAmount(user), minStakingAmount, "Stake persists"
        );
        (uint256 yieldAfter,) = staking.calculateYield(user);
        assertEq(yieldAfter, 0, "Claimable yield resets after claim");
    }

    function testWithdrawBeforeEpochEnds() public {
        vm.prank(user);
        mockToken.approve(address(staking), minStakingAmount);
        uint256 balanceBefore = mockToken.balanceOf(user);

        vm.prank(user);
        staking.stake(minStakingAmount);

        vm.warp(block.timestamp + 10 days);
        vm.prank(user);
        staking.withdraw();

        assertEq(
            mockToken.balanceOf(user), balanceBefore, "Only principal returned"
        );
        assertEq(staking.getStakedAmount(user), 0, "Stake should be 0");
        assertEq(staking.claimableYield(user), 0, "Claimable yield remains 0");
    }

    function testWithdrawMultipleEpochs() public {
        vm.prank(user);
        mockToken.approve(address(staking), minStakingAmount);
        uint256 balanceBefore = mockToken.balanceOf(user);

        vm.prank(user);
        staking.stake(minStakingAmount);

        // Warp to Epoch 3 start
        uint256 epoch3Start = staking.epochStart() + (3 * EPOCH_DURATION);
        vm.warp(epoch3Start);
        vm.deal(address(staking), 10 ether);

        (uint256 expectedYield,) = staking.calculateYield(user);
        assertGt(expectedYield, 0.25 ether, "Yield should be ~=0.3 ETH");

        vm.prank(user);
        staking.withdraw();

        assertEq(mockToken.balanceOf(user), balanceBefore, "Principal returned");
        assertEq(user.balance, expectedYield, "Yield paid in native");
        assertEq(staking.getStakedAmount(user), 0, "Stake should be 0");
        assertEq(staking.claimableYield(user), 0, "Claimable yield resets");
    }

    function testAdminFunctions() public {
        uint256 newYield = 19_290_123_456;
        vm.prank(admin);
        staking.setYieldRate(newYield);
        assertEq(staking.yieldRate(), newYield, "Yield rate not updated");

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
        vm.prank(user);
        mockToken.approve(address(staking), 2 * minStakingAmount);

        vm.prank(user);
        staking.stake(minStakingAmount);

        // Warp to Epoch 1 and stake again
        vm.warp(staking.epochStart() + EPOCH_DURATION + 1);
        vm.prank(user);
        staking.stake(minStakingAmount);

        assertEq(
            staking.getStakedAmount(user),
            2 ether,
            "Total stake should be 2 ETH"
        );
    }

    function testClaimableYieldStorageBeforeInteraction() public {
        vm.prank(user);
        mockToken.approve(address(staking), minStakingAmount);
        vm.prank(user);
        staking.stake(minStakingAmount);

        vm.warp(staking.epochStart() + (3 * EPOCH_DURATION));
        assertEq(
            staking.claimableYield(user),
            0,
            "Claimable yield in storage is 0 before interaction"
        );
        (uint256 totalClaimableYield,) = staking.calculateYield(user);
        assertGt(
            totalClaimableYield,
            0.29 ether,
            "Total claimable yield shows correctly"
        );
    }
}
