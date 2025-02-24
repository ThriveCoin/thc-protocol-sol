// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {CommunityStakingBonusReward} from "../src/CommunityStakingBonusReward.sol";

contract CommunityStakingBonusRewardTest is Test {
    CommunityStakingBonusReward bonusReward;
    // For testing, the default msg.sender (this contract) is the owner.
    address owner = address(this);
    address nonOwner = address(0xBEEF);
    address user = address(0xCAFE);
    // Dummy staking contract address and community id for initialization.
    address dummyStaking = address(0x1234);
    uint256 communityId = 42;

    // Expected events from the contract.
    event RewardClaimed(address indexed user, uint256 amount);
    event ContributionUpdated(address indexed user, uint256 percentage);
    event ContributionDataRequested(address indexed user, uint256 communityId);

    function setUp() public {
        bonusReward = new CommunityStakingBonusReward();
        bonusReward.initialize(dummyStaking, communityId);
    }

    function testInitialization() public view {
        assertEq(bonusReward.thriveStakingContract(), dummyStaking);
        assertEq(bonusReward.communityId(), communityId);
        assertEq(bonusReward.owner(), owner);
    }

    function testFulfillContributionDataByOwner() public {
        uint256 percentage = 50;
        vm.expectEmit(true, false, false, true);
        emit ContributionUpdated(user, percentage);
        bonusReward.fulfillContributionData(user, percentage);
        assertEq(bonusReward.userRewardPercentage(user), percentage);
    }

    function testFulfillContributionDataRevertsForNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        bonusReward.fulfillContributionData(user, 50);
    }

    function testClaimRewardEmitsContributionDataRequestedWhenNoPercentage() public {
        // If user has no contribution percentage set, the contract should emit a request event.
        vm.prank(user);
        vm.expectEmit(true, false, false, true);
        emit ContributionDataRequested(user, communityId);
        bonusReward.claimReward();
        // And the mapping remains zero.
        assertEq(bonusReward.userRewardPercentage(user), 0);
    }

    function testClaimRewardRevertsWhenPoolBalanceZero() public {
        // Set contribution percentage for the user but do not deposit any funds.
        bonusReward.fulfillContributionData(user, 50);
        vm.prank(user);
        vm.expectRevert("Insufficient pool balance");
        bonusReward.claimReward();
    }

    function testClaimRewardSuccess() public {
        // Owner deposits funds into the contract.
        uint256 depositAmount = 100 ether;
        vm.deal(owner, depositAmount);
        bonusReward.deposit{value: depositAmount}();
        
        // Set a contribution percentage for the user.
        uint256 percentage = 25; // i.e. the user is entitled to 25% of the pool.
        bonusReward.fulfillContributionData(user, percentage);
        
        // Set an initial balance for the user.
        vm.deal(user, 1 ether);
        uint256 initialUserBalance = user.balance;
        
        // Expected reward = (depositAmount * percentage) / 100 = 25 ether.
        uint256 expectedReward = (depositAmount * percentage) / 100;
        
        vm.prank(user);
        vm.expectEmit(true, false, false, true);
        emit RewardClaimed(user, expectedReward);
        bonusReward.claimReward();
        
        uint256 finalUserBalance = user.balance;
        assertEq(finalUserBalance, initialUserBalance + expectedReward);
        // Check that the user's claimed reward is recorded.
        assertEq(bonusReward.userClaimed(user), expectedReward);
        // And that the user's contribution percentage is reset.
        assertEq(bonusReward.userRewardPercentage(user), 0);
        // The contract balance should have decreased by the reward amount.
        assertEq(address(bonusReward).balance, depositAmount - expectedReward);
    }

    function testDepositOnlyOwner() public {
        vm.deal(nonOwner, 1 ether);
        vm.prank(nonOwner);
        vm.expectRevert();
        bonusReward.deposit{value: 1 ether}();
    }

    function testReceiveFallback() public {
        uint256 sendAmount = 1 ether;
        // Send ETH directly to the contract.
        (bool success, ) = payable(address(bonusReward)).call{value: sendAmount}("");
        require(success, "Direct send failed");
        assertEq(address(bonusReward).balance, sendAmount);
    }
}
