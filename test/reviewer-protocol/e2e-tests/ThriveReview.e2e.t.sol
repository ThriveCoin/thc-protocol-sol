// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// This test suite is designed to provide comprehensive end-to-end coverage of the Thrive reviewer protocol.
// It ensures the proper functionality of the reviewer protocol and its integrations with related components.

import "../../../src/ThriveWorkerUnitFactory.sol";
import "../../../src/reviewer-protocol/ThriveReviewFactory.sol";
import "../../../src/reviewer-protocol/ThriveReview.sol";

import "../BasicTestConfigs.t.sol";

import {MockERC20} from "test/mock/MockERC20.sol";

import {Test} from "forge-std/Test.sol";

// OpenZeppelin imports
import "openzeppelin-foundry-upgrades/Upgrades.sol";

contract ThriveReviewE2ETests is Test, BasicTestConfigs {
    using Upgrades for address;

    ThriveWorkerUnitFactory thriveWorkerUnitFactory;
    ThriveReviewFactory thriveReviewFactory;
    ThriveReview thriveReviewImplementation;

    address randomUser = address(0x1234);

    address thriveReviewFactoryAddress;

    address thriveReviewAddress;
    address thriveWorkerUnitAddress;

    ThriveReview thriveReview;

    MockERC20 mockToken;

    /// USERS

    address submitter2 = address(0x2);
    address submitter3 = address(0x3);
    address submitter4 = address(0x4);

    address reviewer1 = address(0x11);
    address reviewer2 = address(0x12);
    address reviewer3 = address(0x13);
    address reviewer4 = address(0x14);

    uint256 currentBlockTimestamp;

    function setUp() public {
        // Deploy ThriveWorkerUnitFactory
        thriveWorkerUnitFactory = new ThriveWorkerUnitFactory();

        // Deploy ThriveReview implementation
        thriveReviewImplementation = new ThriveReview();

        // Mock token for paying successful submissions
        mockToken = new MockERC20("MockToken", "MKT");
        mockToken.mint(address(this), 1_000_000 ether);

        workUnitArgs.rewardToken = address(mockToken);
        workUnitArgs.deadline = 15 days;

        // Deploy using UUPS standard
        thriveReviewFactoryAddress = Upgrades.deployUUPSProxy(
            "ThriveReviewFactory.sol",
            abi.encodeCall(
                ThriveReviewFactory.initialize,
                (
                    address(thriveWorkerUnitFactory),
                    address(thriveReviewImplementation),
                    badgeQueryContractAddress,
                    address(this) // owner
                )
            )
        );

        // Instantiate the ThriveReviewFactory contract
        thriveReviewFactory = ThriveReviewFactory(thriveReviewFactoryAddress);

        thriveReviewFactory = ThriveReviewFactory(thriveReviewFactoryAddress);
        mockToken.transfer(address(thriveWorkerUnitFactory), 9000 ether);
        mockToken.approve(address(thriveWorkerUnitFactory), 9000 ether);
        // Create a ThriveWorkUnit and ThriveReview contract
        (thriveReviewAddress, thriveWorkerUnitAddress) = thriveReviewFactory
            .createWorkUnitAndReviewContract{value: 9000 ether}(
            workUnitArgs, reviewConfiguration, address(this)
        );

        // Instantiate the ThriveReview contract
        thriveReview = ThriveReview(payable(thriveReviewAddress));

        mockToken.approve(address(thriveWorkerUnitAddress), 1_000 ether);

        // Initialize the ThriveWorkerUnit contract
        // IThriveWorkerUnit(thriveWorkerUnitAddress).initialize();

        // Add required badge to ThriveWorkerUnit
        IThriveWorkerUnit(thriveWorkerUnitAddress).addRequiredBadge(
            keccak256("TestBadge")
        );

        // https://book.getfoundry.sh/cheatcodes/mock-call
        // Because of this `mockCall`, the badgeQuery contract will always return true for badge authorization
        vm.mockCall(
            badgeQueryContractAddress,
            abi.encodeWithSelector(IBadgeQuery.hasBadge.selector),
            abi.encode(true)
        );

        // Give addresses funds
        vm.deal(randomUser, 1 ether);
        vm.deal(address(0x1), 1 ether);
        vm.deal(address(0x2), 1 ether);
        vm.deal(address(0x3), 1 ether);
        vm.deal(address(0x4), 1 ether);
        vm.deal(address(0x5), 1 ether);

        // Helper variable that calculates submitter amount needed to create a submission
        SUBMITTER_LOCKED_FUNDS = reviewConfiguration.reviewerReward
            * reviewConfiguration.maximumReviewsPerSubmission;

        // Set current block.timestamp in a variable
        currentBlockTimestamp = block.timestamp;
    }

    // Ensure all state storage is valid and payouts are done correctly (on reviewer protocol and on ThriveWorkerUnit)
    // Test is MEANT TO BE COMPLEX TO FOLLOW because it is trying to emulate a real-world scenario
    function test_FullEnd2EndPathOfReviewerProtocol() public {
        /// We will have 5 submissions
        /// 1st submission will be rejected
        /// 2nd submission will be accepted
        /// 3rd submission will be accepted by 75%
        /// 4th submission will be judged by judge badge        - Will be disputed

        // Create first submission for user 1 - this one will be rejected
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission); // id: 0

        // Create second submission for user 2 - this one will be accepted
        vm.prank(submitter2);
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission); // id: 1

        // Reviewer 1 commits to review submission 1 and 2
        vm.prank(reviewer1);
        thriveReview.commitToReview(0); // id: 0

        vm.prank(reviewer1);
        thriveReview.commitToReview(1); // id: 1

        // Reviewer 2 commits to review submission 1 and 2
        vm.prank(reviewer2);
        thriveReview.commitToReview(0); // id: 2

        vm.prank(reviewer2);
        thriveReview.commitToReview(1); // id: 3

        // Create third submission for user 3 - this one will be accepted
        vm.prank(submitter3);
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission); // id: 2

        // Reviewer 2 creates reviews for submission 1 and 2
        vm.prank(reviewer2);
        review.id = 2;
        review.decision = IThriveReview.Decision.REJECTED;
        thriveReview.submitReview(review);

        vm.prank(reviewer2);
        review.id = 3;
        review.decision = IThriveReview.Decision.ACCEPTED;
        thriveReview.submitReview(review);

        // Fetch first submission
        (
            uint256 id,
            uint64 reviewCount,
            uint64 acceptedReviewsCount,
            uint64 rejectedReviewsCount,
            ,
            ,
            ,
            ,
            ,
            IThriveReview.Decision decision,
            IThriveReview.SubmissionStatus submissionStatus
        ) = thriveReview.idToSubmission(0);

        // Assert submission storage state is as expected
        assertEq(reviewCount, 1, "Review count should be 1 for submission 0");
        assertEq(
            acceptedReviewsCount,
            0,
            "Accepted reviews count should be 0 for submission 0"
        );
        assertEq(
            rejectedReviewsCount,
            1,
            "Rejected reviews count should be 1 for submission 0"
        );
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.NONE),
            "Decision should be NONE for submission 0"
        );
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.PENDING),
            "Submission status should be PENDING for submission 0"
        );

        // Fetch second submission decision and status
        decision = thriveReview.getSubmissionDecision(1);
        submissionStatus = thriveReview.getSubmissionStatus(1);
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.NONE),
            "Decision should be NONE for submission 1"
        );
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.PENDING),
            "Submission status should be PENDING for submission 1"
        );

        // Reviewer 1 & 2 & 3 commit to review submisison 3
        vm.prank(reviewer1);
        thriveReview.commitToReview(2); // id: 4

        vm.prank(reviewer2);
        thriveReview.commitToReview(2); // id: 5

        vm.prank(reviewer3);
        thriveReview.commitToReview(2); // id: 6

        // Reviewer 3 creates review for submission 3
        vm.prank(reviewer3);
        review.id = 6;
        review.decision = IThriveReview.Decision.ACCEPTED;
        thriveReview.submitReview(review);

        // Reviewer 1 creates review for submission 1 and 2
        vm.prank(reviewer1);
        review.id = 0;
        review.decision = IThriveReview.Decision.REJECTED;
        thriveReview.submitReview(review);

        vm.prank(reviewer1);
        review.id = 1;
        review.decision = IThriveReview.Decision.ACCEPTED;
        thriveReview.submitReview(review);

        // Reviewer 3 commits to review submission 1
        vm.prank(reviewer3);
        thriveReview.commitToReview(0); // id: 7

        // Reviewer 3 creates review for submission 1
        vm.prank(reviewer3);
        review.id = 7;
        review.decision = IThriveReview.Decision.REJECTED;
        thriveReview.submitReview(review);

        // Fetch third submission
        (
            id,
            reviewCount,
            acceptedReviewsCount,
            rejectedReviewsCount,
            ,
            ,
            ,
            ,
            ,
            decision,
            submissionStatus
        ) = thriveReview.idToSubmission(0);

        // Assert submission storage state is as expected
        assertEq(reviewCount, 3, "Review count should be 3 for submission 0");
        assertEq(
            acceptedReviewsCount,
            0,
            "Accepted reviews count should be 0 for submission 0"
        );
        assertEq(
            rejectedReviewsCount,
            3,
            "Rejected reviews count should be 3 for submission 0"
        );
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.REJECTED),
            "Decision should be REJECTED for submission 0"
        );
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status should be FINALIZED for submission 0"
        );

        // Create fourth submission for user 4 - this one will be judged by judge badge
        vm.prank(submitter4);
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission); // id: 3

        // Reviewer 3 commits to review submission 2
        vm.prank(reviewer3);
        thriveReview.commitToReview(1); // id: 8

        // Reviewer 3 creates review for submission 2
        vm.prank(reviewer3);
        review.id = 8;
        review.decision = IThriveReview.Decision.ACCEPTED;
        thriveReview.submitReview(review);

        // Fetch second submission status
        decision = thriveReview.getSubmissionDecision(1);
        submissionStatus = thriveReview.getSubmissionStatus(1);
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.ACCEPTED),
            "Decision should be REJECTED for submission 1"
        );
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status should be FINALIZED for submission 1"
        );

        // Reviewer 4 commits to review submission 3
        vm.prank(reviewer4);
        thriveReview.commitToReview(2); // id: 9

        // Reviewer 4 creates review for submission 3
        vm.prank(reviewer4);
        review.id = 9;
        review.decision = IThriveReview.Decision.REJECTED;
        thriveReview.submitReview(review);

        // Reviewer 1 creates review for submission 3
        vm.prank(reviewer1);
        review.id = 4;
        review.decision = IThriveReview.Decision.ACCEPTED;
        thriveReview.submitReview(review);

        // Reviewer 4 commits to review submission 4
        vm.prank(reviewer4);
        thriveReview.commitToReview(3); // id: 10

        // Reviewer 3 commits to review submission 4
        vm.prank(reviewer3);
        thriveReview.commitToReview(3); // id: 11

        // Reviewer 3 creates review for submission 4
        vm.prank(reviewer3);
        review.id = 11;
        review.decision = IThriveReview.Decision.REJECTED;
        thriveReview.submitReview(review);

        // Reviewer 2 creates review for submission 3
        vm.prank(reviewer2);
        review.id = 5;
        review.decision = IThriveReview.Decision.ACCEPTED;
        thriveReview.submitReview(review);

        // Fetch submission 3
        (
            ,
            reviewCount,
            acceptedReviewsCount,
            rejectedReviewsCount,
            ,
            ,
            ,
            ,
            ,
            decision,
            submissionStatus
        ) = thriveReview.idToSubmission(2);

        // Assert submission storage state is as expected
        assertEq(reviewCount, 4, "Review count should be 3 for submission 2");
        assertEq(
            acceptedReviewsCount,
            3,
            "Accepted reviews count should be 2 for submission 2"
        );
        assertEq(
            rejectedReviewsCount,
            1,
            "Rejected reviews count should be 1 for submission 2"
        );
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.ACCEPTED),
            "Decision should be ACCEPTED for submission 2"
        );
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status should be FINALIZED for submission 2"
        );

        // Check submission 3 submitter and reviewers balances before finalization
        uint256 submitter3BalanceBefore = address(submitter3).balance;
        uint256 submitter3TokenBalanceBefore = mockToken.balanceOf(submitter3);

        // Go to after dispute timestamp
        vm.warp(currentBlockTimestamp + 2 days + 1);

        // Pay out rewards for submission 3
        thriveReview.distributePayoutsForNonDisputedSubmission(2);

        // Check submission 3 submitter and reviewers balances after finalization/payouts
        uint256 submitter3BalanceAfter = address(submitter3).balance;
        uint256 submitter3TokenBalanceAfter = mockToken.balanceOf(submitter3);

        // Check the prize payout from WorkerUnit
        uint256 rewardAmountOnWorkerUnit =
            IThriveWorkerUnit(thriveWorkerUnitAddress).rewardAmount();

        // Assert balances are as expected
        assertEq(
            submitter3BalanceAfter,
            submitter3BalanceBefore + SUBMITTER_LOCKED_FUNDS,
            "Submitter 3 balance should be increased by locked funds return"
        );
        assertEq(
            submitter3TokenBalanceAfter,
            submitter3TokenBalanceBefore + rewardAmountOnWorkerUnit,
            "Submitter 3 token balance should be increased by reward amount"
        );

        // Reviewer 4 creates review for submission 4
        vm.prank(reviewer4);
        review.id = 10;
        review.decision = IThriveReview.Decision.REJECTED;
        vm.expectRevert("Review commitment deadline has passed");
        thriveReview.submitReview(review);

        // Reviewer 1 commits to review submission 4
        vm.prank(reviewer1);
        thriveReview.commitToReview(3); // id: 12

        // Reviewer 1 creates review for submission 4
        vm.prank(reviewer1);
        review.id = 12;
        review.decision = IThriveReview.Decision.ACCEPTED;
        thriveReview.submitReview(review);

        // Reviewer 2 commits to review submission 4
        vm.prank(reviewer2);
        thriveReview.commitToReview(3); // id: 13

        // Reviewer 2 creates review for submission 4
        vm.prank(reviewer2);
        review.id = 13;
        thriveReview.submitReview(review);

        // Ensure submission 4 is in the correct state
        decision = thriveReview.getSubmissionDecision(3);
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.NONE),
            "Decision should be NONE for submission 3"
        );

        // Go to after review deadline for submission 4
        vm.warp(currentBlockTimestamp + 10 days + 1);

        // We can judge the submission as a badge since decision is not reached after max reviews
        thriveReview.reachDecisionOnSubmissionAsJudge(
            3, IThriveReview.Decision.REJECTED, ""
        );

        // Ensure submission 4 is in the correct state
        decision = thriveReview.getSubmissionDecision(3);
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.REJECTED),
            "Decision should be REJECTED for submission 4"
        );

        // Raise dispute for submission 4
        vm.prank(reviewer3);
        thriveReview.raiseDisputeOnSubmission(3, "");

        // Check submission 4 status
        submissionStatus = thriveReview.getSubmissionStatus(3);
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.DISPUTED),
            "Submission status should be DISPUTED for submission 4"
        );

        // Check submission 3 submitter and reviewers balances before finalization
        uint256 submitter4BalanceBefore = address(submitter4).balance;
        uint256 submitter4TokenBalanceBefore = mockToken.balanceOf(submitter4);
        uint256 reviewer1BalanceBefore = address(reviewer1).balance;
        uint256 reviewer2BalanceBefore = address(reviewer2).balance;
        uint256 reviewer3BalanceBefore = address(reviewer3).balance;

        // Dispute badge resolves dispute
        thriveReview.resolveDisputeOnSubmission(
            3, IThriveReview.Decision.ACCEPTED, ""
        );

        // Check that submission 4 is finalized
        submissionStatus = thriveReview.getSubmissionStatus(3);
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.PAID_OUT),
            "Submission status should be FINALIZED for submission 4"
        );

        // Check that submission 4 is accepted
        decision = thriveReview.getSubmissionDecision(3);
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.ACCEPTED),
            "Decision should be ACCEPTED for submission 4"
        );

        // Check submission 3 submitter and reviewers balances after finalization/payouts
        uint256 submitter4BalanceAfter = address(submitter4).balance;
        uint256 submitter4TokenBalanceAfter = mockToken.balanceOf(submitter4);
        uint256 reviewer1BalanceAfter = address(reviewer1).balance;
        uint256 reviewer2BalanceAfter = address(reviewer2).balance;
        uint256 reviewer3BalanceAfter = address(reviewer3).balance;

        // Ensure balances are updated correctly
        assertEq(
            submitter4BalanceAfter,
            submitter4BalanceBefore + SUBMITTER_LOCKED_FUNDS,
            "Submitter 4 balance should be increased by locked funds return"
        );
        assertEq(
            submitter4TokenBalanceAfter,
            submitter4TokenBalanceBefore + rewardAmountOnWorkerUnit,
            "Submitter 4 token balance should be increased by reward amount"
        );
        assertEq(
            reviewer1BalanceAfter,
            reviewer1BalanceBefore + reviewConfiguration.reviewerReward,
            "Reviewer 1 balance should be increased by reviewer reward"
        );
        assertEq(
            reviewer2BalanceAfter,
            reviewer2BalanceBefore + reviewConfiguration.reviewerReward,
            "Reviewer 2 balance should be increased by reviewer reward"
        );
        assertEq(
            reviewer3BalanceAfter,
            reviewer3BalanceBefore,
            "Reviewer 3 balance should be increased by reviewer reward"
        );
    }
}
