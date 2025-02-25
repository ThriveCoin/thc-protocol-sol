// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {CommunityStakingBonusReward} from
    "../src/CommunityStakingBonusReward.sol";

contract CommunityStakingBonusRewardTest is Test {
    CommunityStakingBonusReward bonusReward;
    address owner = address(this);
    address nonOwner = address(0xBEEF);
    address user = address(0xCAFE);
    address dummyStaking = address(0x1234);
    uint256 communityId = 42;

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

    function testClaimRewardEmitsContributionDataRequestedWhenNoPercentage()
        public
    {
        vm.prank(user);
        vm.expectEmit(true, false, false, true);

        emit ContributionDataRequested(user, communityId);

        bonusReward.claimReward();
        assertEq(bonusReward.userRewardPercentage(user), 0);
    }

    function testClaimRewardRevertsWhenPoolBalanceZero() public {
        bonusReward.fulfillContributionData(user, 50);
        vm.prank(user);
        vm.expectRevert("Insufficient pool balance");
        bonusReward.claimReward();
    }

    function testClaimRewardSuccess() public {
        uint256 depositAmount = 100 ether;
        vm.deal(owner, depositAmount);
        bonusReward.deposit{value: depositAmount}();

        uint256 percentage = 25; // i.e. the user is entitled to 25% of the pool.
        bonusReward.fulfillContributionData(user, percentage);

        vm.deal(user, 1 ether);
        uint256 initialUserBalance = user.balance;

        uint256 expectedReward = (depositAmount * percentage) / 100;

        vm.prank(user);
        vm.expectEmit(true, false, false, true);

        emit RewardClaimed(user, expectedReward);

        bonusReward.claimReward();
        uint256 finalUserBalance = user.balance;

        assertEq(finalUserBalance, initialUserBalance + expectedReward);
        assertEq(bonusReward.userClaimed(user), expectedReward);
        assertEq(bonusReward.userRewardPercentage(user), 0);
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
        (bool success,) =
            payable(address(bonusReward)).call{value: sendAmount}("");
        require(success, "Direct send failed");

        assertEq(address(bonusReward).balance, sendAmount);
    }
}
