// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// This file contains unit tests for the reviewer protocol.
// The primary objectives are to validate proper authorization, enforce contract restrictions, ensure functions handle data correctly and operate as intended/per specs.
// Note: Event testing is not included in this file.

// How to run tests:
// forge clean && forge test

// How to run coverage:
// forge clean && forge coverage --ir-minimum

// Foundry imports
import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../../src/ThriveWorkerUnitFactory.sol";
import "../../../src/reviewer-protocol/ThriveReviewFactory.sol";
import "../../../src/reviewer-protocol/ThriveReview.sol";
import "../../../src/interface/IThriveWorkerUnit.sol";

import "../BasicTestConfigs.t.sol";

import {MockERC20} from "test/mock/MockERC20.sol";

// @openzeppelin-upgrades
import "openzeppelin-foundry-upgrades/Upgrades.sol";

contract ThriveReviewUnitTests is Test, BasicTestConfigs {
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

        // Set current block timestamp
        currentBlockTimestamp = block.timestamp;

        // Helper variable that calculates submitter amount needed to create a submission
        SUBMITTER_LOCKED_FUNDS = reviewConfiguration.reviewerReward
            * reviewConfiguration.maximumReviewsPerSubmission;
    }

    ////////////////////////////////////////////////////////
    //                 BASIC CONFIG TESTS                 //
    ////////////////////////////////////////////////////////

    function test_000_revert_CanNotInitializeReviewContractTwice() public {
        // Try to initialize the ThriveReview contract again
        bytes4 selector = bytes4(keccak256("InvalidInitialization()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        thriveReview.initialize(
            reviewConfiguration,
            thriveReviewFactoryAddress,
            badgeQueryContractAddress,
            msg.sender
        );
    }

    function test_001_success_ReviewContractInitializedCorrectly()
        public
        view
    {
        // Assert storage variables are initialized properly
        assertEq(
            address(thriveReview.workerUnitAddress()),
            thriveWorkerUnitAddress,
            "WorkUnit address is not set correctly"
        );
        assertEq(
            thriveReview.thriveReviewFactoryAddress(),
            thriveReviewFactoryAddress,
            "thriveReviewFactoryAddress not set correctly"
        );
        assertEq(
            thriveReview.badgeQueryContractAddress(),
            badgeQueryContractAddress,
            "badgeQueryContract address not set correctly"
        );
        assertEq(
            thriveReview.owner(),
            address(this),
            "Owner should be the contract creator"
        );
    }

    function test_002_revert_AgreementThresholdCanNotBe50PercentOrLower()
        public
    {
        // Set agreement threshold to 50%
        reviewConfiguration.agreementThreshold = 5000;

        // Expect to revert because agreement threshold is too low
        vm.expectRevert();
        (thriveReviewAddress, thriveWorkerUnitAddress) = thriveReviewFactory
            .createWorkUnitAndReviewContract{value: REVIEW_CONTRACT_ALLOCATION}(
            workUnitArgs, reviewConfiguration, address(this)
        );

        // Set agreement threshold to less than 50%
        reviewConfiguration.agreementThreshold = 4567;
        vm.expectRevert();
        (thriveReviewAddress, thriveWorkerUnitAddress) = thriveReviewFactory
            .createWorkUnitAndReviewContract{value: REVIEW_CONTRACT_ALLOCATION}(
            workUnitArgs, reviewConfiguration, address(this)
        );
    }

    function test_003_revert_CanNotInitializeIfThereIsNotEnoughFundsOnWorkerUnit(
    ) public {
        // Allow more submissions than there is funds to be paid out on worker unit
        reviewConfiguration.maximumSubmissions = 100;

        // Expect to revert because of lack of funds on worker unit
        vm.expectRevert();
        (thriveReviewAddress, thriveWorkerUnitAddress) = thriveReviewFactory
            .createWorkUnitAndReviewContract{value: 10 ether}(
            workUnitArgs, reviewConfiguration, address(this)
        );
    }

    // This test can be uncommented and run with: --via-ir flag
    function test_004_success_ReviewConfigurationVariablesCorrectlyStored()
        public
        view
    {
        /*
        ///// Badges are tested in access control tests

        (address workUnit, uint256 reviewerRewardsTotalAllocation, uint256 reviewerReward, 
        uint32 agreementThreshold, uint32 maximumSubmissionsPerUser, uint32 minimumReviews, uint32 maximumSubmissions,
        uint32 maximumReviewsPerSubmission, uint32 submissionDeadline, uint32 reviewCommitmentDeadline, uint32 reviewDeadline,
        string memory reviewMetadata, string memory submissionMetadata) = thriveReview.reviewConfiguration();

        // Assert review configuration is initialized properly
        assertEq(workUnit, thriveWorkerUnitAddress, "WorkUnit address is not set correctly");
        assertEq(reviewerRewardsTotalAllocation, reviewConfiguration.reviewerRewardsTotalAllocation, "reviewerRewardsTotalAllocation is not set correctly");
        assertEq(reviewerReward, reviewConfiguration.reviewerReward, "reviewerReward is not set correctly");
        assertEq(agreementThreshold, reviewConfiguration.agreementThreshold, "agreementThreshold is not set correctly");
        assertEq(maximumSubmissionsPerUser, reviewConfiguration.maximumSubmissionsPerUser, "maximumSubmissionsPerUser is not set correctly");
        assertEq(minimumReviews, reviewConfiguration.minimumReviews, "minimumReviews is not set correctly");
        assertEq(maximumSubmissions, reviewConfiguration.maximumSubmissions, "maximumSubmissions is not set correctly");
        assertEq(maximumReviewsPerSubmission, reviewConfiguration.maximumReviewsPerSubmission, "maximumReviewsPerSubmission is not set correctly");
        assertEq(submissionDeadline, reviewConfiguration.submissionDeadline, "submissionDeadline is not set correctly");
        assertEq(reviewCommitmentDeadline, reviewConfiguration.reviewCommitmentDeadline, "reviewCommitmentDeadline is not set correctly");
        assertEq(reviewDeadline, reviewConfiguration.reviewDeadline, "reviewDeadline is not set correctly");
        assertEq(reviewMetadata, reviewConfiguration.reviewMetadata, "reviewMetadata is not set correctly");
        assertEq(submissionMetadata, reviewConfiguration.submissionMetadata, "submissionMetadata is not set correctly");
        
        */
    }

    ////////////////////////////////////////////////////////
    //                 SUBMISSION TESTS                   //
    ////////////////////////////////////////////////////////

    function test_100_revert_UserCanNotHaveMoreThanOnePendingSubmission()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        vm.expectRevert("User has a pending submission");
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);
    }

    function test_101_revert_UserCanNotHaveMoreThanOneAcceptedSubmission()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        /**
         * JUDGE ON FIRST SUBMISSION - ACCEPT IT
         */

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.submitReview(review);

        vm.prank(address(0x1));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x1));
        // Create a review
        review.id = 1;
        thriveReview.submitReview(review);

        vm.prank(address(0x2));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x2));
        // Create a review
        review.id = 2;
        thriveReview.submitReview(review);

        // Check that the submission is finalized
        IThriveReview.Decision decision = thriveReview.getSubmissionDecision(0);
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.ACCEPTED),
            "Submission status is not set correctly"
        );
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status is not set correctly"
        );

        // Create a submission
        vm.expectRevert("User already has an accepted submission");
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);
    }

    function test_102_revert_UserCanNotHaveMoreThanMaximumSubmissionsPerUser()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        /**
         * JUDGE ON FIRST SUBMISSION - REJECT IT
         */

        // Commit to review
        thriveReview.commitToReview(0);

        review.decision = IThriveReview.Decision.REJECTED;
        // Create a review
        thriveReview.submitReview(review);

        vm.prank(address(0x1));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x1));
        // Create a review
        review.id = 1;
        thriveReview.submitReview(review);

        vm.prank(address(0x2));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x2));
        // Create a review
        review.id = 2;
        thriveReview.submitReview(review);

        // Check that the submission is finalized
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status is not set correctly"
        );

        // Create another submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        /**
         * JUDGE ON SECOND SUBMISSION - REJECT IT
         */

        // Commit to review
        thriveReview.commitToReview(1);

        // Create a review
        review.id = 3;
        thriveReview.submitReview(review);

        vm.prank(address(0x1));
        // Commit to a review
        thriveReview.commitToReview(1);

        vm.prank(address(0x1));
        // Create a review
        review.id = 4;
        thriveReview.submitReview(review);

        vm.prank(address(0x2));
        // Commit to a review
        thriveReview.commitToReview(1);

        vm.prank(address(0x2));
        // Create a review
        review.id = 5;
        thriveReview.submitReview(review);

        // Check that the submission is finalized
        submissionStatus = thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status is not set correctly"
        );

        // Try to create another submission, but can not because the user has reached the maximum submissions
        vm.expectRevert("User has reached the maximum number of submissions");
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);
    }

    function test_103_revert_UserCanNotSubmitWhenThereAreMaximumSubmissions()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Create a submission
        vm.prank(address(0x1));
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Create a submission
        vm.prank(address(0x2));
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Create a submission
        vm.prank(address(0x3));
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Create a submission
        vm.prank(address(0x4));
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Create a submission
        vm.prank(address(0x5));
        vm.expectRevert("Maximum amount of submissions has been reached");
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);
    }

    function test_104_revert_UserCanNotSubmitAfterSubmissionDeadline() public {
        // Go to time after submission deadline
        vm.warp(reviewConfiguration.submissionDeadline + 1);

        vm.expectRevert("Submission deadline has passed");
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);
    }

    function test_105_success_SubmissionStateIsCorrectlyStoredOnchain()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Get the submission
        (
            uint256 id,
            uint64 reviewCount,
            uint64 acceptedReviewCount,
            uint64 rejectedReviewCount,
            ,
            ,
            address contributor,
            string memory submissionMetadata,
            ,
            IThriveReview.Decision decision,
            IThriveReview.SubmissionStatus status
        ) = thriveReview.idToSubmission(0);

        // Assert submission is stored correctly
        assertEq(id, 0, "Submission id is not set correctly");
        assertEq(
            contributor,
            submission.contributor,
            "Contributor is not set correctly"
        );
        assertEq(
            submissionMetadata,
            submission.submissionMetadata,
            "Submission metadata is not set correctly"
        );
        assertEq(
            uint256(status),
            uint256(IThriveReview.SubmissionStatus.PENDING),
            "Review status is not set correctly"
        );

        assertEq(reviewCount, 0, "Review count is not set correctly");
        assertEq(
            acceptedReviewCount, 0, "Accepted review count is not set correctly"
        );
        assertEq(
            rejectedReviewCount, 0, "Rejected review count is not set correctly"
        );

        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.NONE),
            "Decision is not set correctly"
        );

        // Fetch user submissions
        uint256 userSubmissionId =
            thriveReview.userSubmissions(address(this), 0);
        assertEq(
            userSubmissionId, 0, "User submissions ids are not set correctly"
        );
    }

    function test_106_success_SubmissionDataIsUpdatedOnchain() public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        submission.submissionMetadata = "Updated submission metadata";

        // Update the submission
        thriveReview.updateSubmission(submission.submissionMetadata, 0);

        // Get the submission
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            string memory submissionMetadata,
            ,
            IThriveReview.Decision decision,
            IThriveReview.SubmissionStatus status
        ) = thriveReview.idToSubmission(0);

        // Assert submission is stored correctly
        assertEq(
            submissionMetadata,
            "Updated submission metadata",
            "Submission metadata is not set correctly"
        );
        assertEq(
            uint256(status),
            uint256(IThriveReview.SubmissionStatus.PENDING),
            "Review status is not set correctly"
        );
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.NONE),
            "Decision is not set correctly"
        );
    }

    function test_107_revert_FailToUpdateSubmissionAfterSubmissionDeadline()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Go to time after submission deadline
        vm.warp(reviewConfiguration.submissionDeadline + 1);

        vm.expectRevert("Submission deadline has passed");
        thriveReview.updateSubmission(submission.submissionMetadata, 0);
    }

    function test_108_revert_FailToUpdateSubmissionMadeByAnotherUser() public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        vm.prank(randomUser);

        vm.expectRevert("Caller has not submitted this submission");
        thriveReview.updateSubmission(submission.submissionMetadata, 0);
    }

    function test_109_revert_FailToUpdateSubmissionThatAlreadyHasReviews()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.submitReview(review);

        vm.expectRevert("Submission has reviews");
        thriveReview.updateSubmission(submission.submissionMetadata, 0);
    }

    function test_110_revert_FailToUpdateSubmissionThatIsNotPending() public {
        // Create submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        /**
         * JUDGE ON SUBMISSION
         */

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.submitReview(review);

        vm.prank(address(0x1));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x1));
        // Create a review
        review.id = 1;
        thriveReview.submitReview(review);

        vm.prank(address(0x2));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x2));
        // Create a review
        review.id = 2;
        thriveReview.submitReview(review);

        // Check that the submission is finalized
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status is not set correctly"
        );

        vm.expectRevert("Submission is not in 'PENDING' status");
        thriveReview.updateSubmission(submission.submissionMetadata, 0);
    }

    ////////////////////////////////////////////////////////
    //                    REVIEW TESTS                    //
    ////////////////////////////////////////////////////////

    function test_200_success_UserCommitsToReview() public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Get the review
        (
            uint256 id,
            uint256 submissionId,
            address reviewer,
            string memory reviewMetadata,
            uint256 deadline,
            IThriveReview.Decision decision,
            IThriveReview.ReviewStatus status
        ) = thriveReview.reviews(0);

        // Assert review is stored correctly
        assertEq(id, 0, "Review id is not set correctly");
        assertEq(submissionId, 0, "Submission id is not set correctly");
        assertEq(reviewer, address(this), "Reviewer is not set correctly");
        assertEq(reviewMetadata, "", "Review metadata is not set correctly");
        assertEq(
            deadline,
            currentBlockTimestamp + reviewConfiguration.reviewCommitmentPeriod,
            "Deadline is not set correctly"
        );
        assertEq(
            uint256(status),
            uint256(IThriveReview.ReviewStatus.COMMITTED),
            "Review status is not set correctly"
        );
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.NONE),
            "Decision is not set correctly"
        );

        // Fetch user commmits to review the submission
        uint256 counterOfCommittedReviews =
            thriveReview.committedReviewsPerSubmissionCounter(0);
        assertEq(
            counterOfCommittedReviews,
            1,
            "User review ids are not set correctly"
        );
    }

    function test_201_revert_FailToCommitReviewToTheSameSubmissionTwice()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        vm.expectRevert("User has already committed to review this submission");
        thriveReview.commitToReview(0);
    }

    function test_202_revert_FailToCommitReviewAfterReviewDeadline() public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Go to right after the review deadline to commit
        vm.warp(
            currentBlockTimestamp + reviewConfiguration.reviewDeadlinePeriod + 1
        );

        vm.expectRevert("Review deadline has passed");
        thriveReview.commitToReview(0);
    }

    function test_203_revert_FailToCommitReviewAfterMaximumReviewsPerSubmissionReached(
    ) public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Commit to review
        vm.prank(address(0x3));
        thriveReview.commitToReview(0);

        // Commit to review
        vm.prank(address(0x4));
        thriveReview.commitToReview(0);

        vm.expectRevert("Maximum amount of commits to review has been reached");
        thriveReview.commitToReview(0);
    }

    function test_204_revert_FailToCommitReviewToSubmissionThatIsNotPending()
        public
    {
        // Create submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        /**
         * JUDGE ON SUBMISSION
         */

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.submitReview(review);

        vm.prank(address(0x1));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x1));
        // Create a review
        review.id = 1;
        thriveReview.submitReview(review);

        vm.prank(address(0x2));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x2));
        // Create a review
        review.id = 2;
        thriveReview.submitReview(review);

        // Check that the submission is finalized
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status is not set correctly"
        );

        vm.expectRevert("Submission is not in 'PENDING' status");
        thriveReview.commitToReview(0);
    }

    function test_205_revert_FailToCreateReviewThatWasNotCommitted() public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        vm.expectRevert("User has not committed to this review");
        thriveReview.submitReview(review);
    }

    function test_206_revert_FailToCreateReviewForSubmissionThatIsNotPending()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        review.id = 1;
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x3));
        thriveReview.commitToReview(0);
        // This review will not be created, and later rejected because the submission judging has been finalized

        // Commit to review
        vm.prank(address(0x4));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x4));
        review.id = 3;
        thriveReview.submitReview(review);

        // Now submission has enough reviews to be judged on
        // Check that the submission is finalized
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status is not set correctly"
        );

        // Can not create review because the submission has already been judged on.
        vm.prank(address(0x3));
        vm.expectRevert("Submission is not in 'PENDING' status");
        review.id = 2;
        thriveReview.submitReview(review);
    }

    function test_207_revert_FailToCreateReviewByUserWhoDidNotCommitTheSameReview(
    ) public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Some other user commits to review
        vm.prank(randomUser);
        thriveReview.commitToReview(0);

        // User can not create review committed by someone else
        vm.expectRevert("User is not the committer of this review");
        review.id = 1;
        thriveReview.submitReview(review);
    }

    function test_208_revert_FailToCreateReviewAfterReviewCommitmentDeadline()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Go to right after the review commitment deadline to create review
        vm.warp(
            currentBlockTimestamp + reviewConfiguration.reviewCommitmentPeriod
                + 1
        );

        vm.expectRevert("Review commitment deadline has passed");
        thriveReview.submitReview(review);
    }

    function test_209_revert_FailToCreateReviewAfterReviewDeadline() public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Go to right before the review deadline to commit
        vm.warp(
            currentBlockTimestamp + reviewConfiguration.reviewDeadlinePeriod - 1
        );

        // Commit to review
        thriveReview.commitToReview(0);

        // Go to right after the review deadline to create review
        vm.warp(
            currentBlockTimestamp + reviewConfiguration.reviewDeadlinePeriod + 1
        );

        vm.expectRevert("Review deadline has passed");
        thriveReview.submitReview(review);
    }

    function test_210_revert_FailToCreateReviewWithNonAcceptedDecision()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        review.decision = IThriveReview.Decision.NONE;

        vm.expectRevert(
            "Review decision must be either 'ACCEPTED' or 'REJECTED'"
        );
        thriveReview.submitReview(review);
    }

    function test_211_success_CreateReviewAfterCommittingToIt() public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.submitReview(review);

        // Get the review
        (
            uint256 id,
            uint256 submissionId,
            address reviewer,
            string memory reviewMetadata,
            uint256 deadline,
            IThriveReview.Decision decision,
            IThriveReview.ReviewStatus status
        ) = thriveReview.reviews(0);

        // Assert review is stored correctly
        assertEq(id, 0, "Review id is not set correctly");
        assertEq(submissionId, 0, "Submission id is not set correctly");
        assertEq(reviewer, address(this), "Reviewer is not set correctly");
        assertEq(
            reviewMetadata,
            "reviewMetadata",
            "Review metadata is not set correctly"
        );
        assertEq(
            deadline,
            currentBlockTimestamp + reviewConfiguration.reviewCommitmentPeriod,
            "Deadline is not set correctly"
        );
        assertEq(
            uint256(status),
            uint256(IThriveReview.ReviewStatus.DONE),
            "Review status is not set correctly"
        );
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.ACCEPTED),
            "Decision is not set correctly"
        );

        // Fetch submission after the review
        (
            ,
            uint64 reviewCount,
            uint64 acceptedReviewCount,
            uint64 rejectedReviewCount,
            ,
            ,
            ,
            ,
            ,
            IThriveReview.Decision submissionDecision,
            IThriveReview.SubmissionStatus submissionStatus
        ) = thriveReview.idToSubmission(0);
        assertEq(reviewCount, 1, "Review count is not set correctly");
        assertEq(
            acceptedReviewCount, 1, "Accepted review count is not set correctly"
        );
        assertEq(
            rejectedReviewCount, 0, "Rejected review count is not set correctly"
        );
        assertEq(
            uint256(submissionDecision),
            uint256(IThriveReview.Decision.NONE),
            "Decision is not set correctly"
        );
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.PENDING),
            "Submission status is not set correctly"
        );
    }

    function test_212_success_DeletePendingReviews() public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Commit to another review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Commit to another review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        uint256 committedReviewsPerSubmissionCounter =
            thriveReview.committedReviewsPerSubmissionCounter(0);
        assertEq(
            committedReviewsPerSubmissionCounter,
            3,
            "Committed reviews per submission counter is not set correctly"
        );

        bool userCommittedToReview =
            thriveReview.userCommittedToReview(address(this), 0);
        assertEq(
            userCommittedToReview, true, "User has not committed to review"
        );

        vm.warp(
            currentBlockTimestamp + reviewConfiguration.reviewCommitmentPeriod
                + 1
        );

        // Delete pending reviews
        uint256[] memory reviewIds = new uint256[](3);
        reviewIds[0] = 0;
        reviewIds[1] = 1;
        reviewIds[2] = 2;
        thriveReview.deletePendingReviews(reviewIds);

        // Get the review
        (,,,,,, IThriveReview.ReviewStatus status) = thriveReview.reviews(0);

        // Assert review is deleted
        assertEq(
            uint256(status),
            uint256(IThriveReview.ReviewStatus.NONE),
            "Review status is not set correctly"
        );

        // Get the review
        (,,,,,, status) = thriveReview.reviews(1);

        // Assert review is deleted
        assertEq(
            uint256(status),
            uint256(IThriveReview.ReviewStatus.NONE),
            "Review status is not set correctly"
        );

        // Get the review
        (,,,,,, status) = thriveReview.reviews(2);

        // Assert review is deleted
        assertEq(
            uint256(status),
            uint256(IThriveReview.ReviewStatus.NONE),
            "Review status is not set correctly"
        );

        committedReviewsPerSubmissionCounter =
            thriveReview.committedReviewsPerSubmissionCounter(0);
        assertEq(
            committedReviewsPerSubmissionCounter,
            0,
            "Committed reviews per submission counter is not set correctly"
        );

        userCommittedToReview =
            thriveReview.userCommittedToReview(address(this), 0);
        assertEq(userCommittedToReview, false, "Storage updated incorrectly");
    }

    function test_213_revert_FailToDeleteNonCommittedReview() public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Commit to another review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);
        // Create review by address(0x1)
        thriveReview.submitReview(review);

        vm.warp(
            currentBlockTimestamp + reviewConfiguration.reviewCommitmentPeriod
                + 1
        );

        // Delete pending reviews
        uint256[] memory reviewIds = new uint256[](2);
        reviewIds[0] = 0;
        reviewIds[1] = 1;

        vm.expectRevert("Review is not in 'COMMITTED' status");
        thriveReview.deletePendingReviews(reviewIds);
    }

    function test_214_revert_FailToDeleteNonExpiredCommittedReview() public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Commit to another review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Delete pending reviews
        uint256[] memory reviewIds = new uint256[](2);
        reviewIds[0] = 0;
        reviewIds[1] = 1;

        vm.expectRevert("Review deadline has not passed");
        thriveReview.deletePendingReviews(reviewIds);
    }

    function test_215_success_CorrectReviewersArePaidOutOnAcceptedSubmissionFinalization(
    ) public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.submitReview(review);

        vm.prank(address(0x1));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x1));
        // Create a review
        review.id = 1;
        thriveReview.submitReview(review);

        uint256 balanceBeforeClaimingReward = address(this).balance;
        uint256 balanceAddress1BeforeClaimingReward = address(0x1).balance;
        uint256 balanceAddress2BeforeClaimingReward = address(0x2).balance;
        uint256 balanceAddress3BeforeClaimingReward = address(0x3).balance;

        // Address 2 makes the wrong decision
        review.decision = IThriveReview.Decision.REJECTED;
        vm.prank(address(0x2));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x2));
        // Create a review
        review.id = 2;
        thriveReview.submitReview(review);

        // Address 3 makes the right decision
        review.decision = IThriveReview.Decision.ACCEPTED;
        vm.prank(address(0x3));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x3));
        // Create a review
        review.id = 3;
        thriveReview.submitReview(review);

        // Check that the submission is ACCEPTED
        IThriveReview.Decision decision = thriveReview.getSubmissionDecision(0);
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.ACCEPTED),
            "Submission decision is not set correctly"
        );

        // Go to after dispute deadline
        vm.warp(currentBlockTimestamp + 2 days + 1);

        // Distribute rewards
        thriveReview.distributePayoutsForNonDisputedSubmission(0);

        // Assert balance after rewards distribution and submission finalization
        uint256 balanceAfterClaimingReward = address(this).balance;
        uint256 balanceAddress1AfterClaimingReward = address(0x1).balance;
        uint256 balanceAddress2AfterClaimingReward = address(0x2).balance;
        uint256 balanceAddress3AfterClaimingReward = address(0x3).balance;

        // Original submitter also receives his submitter reserve funds back
        assertEq(
            balanceAfterClaimingReward,
            balanceBeforeClaimingReward + reviewConfiguration.reviewerReward
                + SUBMITTER_LOCKED_FUNDS,
            "Reviewer reward is not claimed correctly"
        );
        assertEq(
            balanceAddress1AfterClaimingReward,
            balanceAddress1BeforeClaimingReward
                + reviewConfiguration.reviewerReward,
            "Reviewer reward is not claimed correctly"
        );
        assertEq(
            balanceAddress2AfterClaimingReward,
            balanceAddress2BeforeClaimingReward,
            "Reviewer reward is not claimed correctly"
        );
        assertEq(
            balanceAddress3AfterClaimingReward,
            balanceAddress3BeforeClaimingReward
                + reviewConfiguration.reviewerReward,
            "Reviewer reward is not claimed correctly"
        );
    }

    function test_216_success_CorrectReviewersArePaidOutOnRejectedSubmissionFinalization(
    ) public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // This decision will be judged DECISION
        review.decision = IThriveReview.Decision.REJECTED;

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.submitReview(review);

        vm.prank(address(0x1));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x1));
        // Create a review
        review.id = 1;
        thriveReview.submitReview(review);

        uint256 balanceBeforeClaimingReward = address(this).balance;
        uint256 balanceAddress1BeforeClaimingReward = address(0x1).balance;
        uint256 balanceAddress2BeforeClaimingReward = address(0x2).balance;
        uint256 balanceAddress3BeforeClaimingReward = address(0x3).balance;

        // Address 2 makes the wrong decision
        review.decision = IThriveReview.Decision.ACCEPTED;
        vm.prank(address(0x2));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x2));
        // Create a review
        review.id = 2;
        thriveReview.submitReview(review);

        // Address 3 makes the right decision
        review.decision = IThriveReview.Decision.REJECTED;
        vm.prank(address(0x3));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x3));
        // Create a review
        review.id = 3;
        thriveReview.submitReview(review);

        // Check that the submission is finalized
        IThriveReview.Decision decision = thriveReview.getSubmissionDecision(0);
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.REJECTED),
            "Submission decision is not set correctly"
        );
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status is not set correctly"
        );

        // Go to after dispute deadline
        vm.warp(currentBlockTimestamp + 2 days + 1);

        // Distribute rewards
        thriveReview.distributePayoutsForNonDisputedSubmission(0);

        // Assert balance after rewards distribution and submission finalization
        uint256 balanceAfterClaimingReward = address(this).balance;
        uint256 balanceAddress1AfterClaimingReward = address(0x1).balance;
        uint256 balanceAddress2AfterClaimingReward = address(0x2).balance;
        uint256 balanceAddress3AfterClaimingReward = address(0x3).balance;

        // Original submitter does NOT receive his reserved funds back, they are used to payout reviewers
        // He receives only reward amounts reserved for reviewers who made the WRONG decision - address(0x2) funds + his CORRECT reviewer reward
        assertEq(
            balanceAfterClaimingReward,
            balanceBeforeClaimingReward + reviewConfiguration.reviewerReward * 2,
            "Reviewer reward is not claimed correctly"
        );
        assertEq(
            balanceAddress1AfterClaimingReward,
            balanceAddress1BeforeClaimingReward
                + reviewConfiguration.reviewerReward,
            "Reviewer reward is not claimed correctly"
        );
        assertEq(
            balanceAddress2AfterClaimingReward,
            balanceAddress2BeforeClaimingReward,
            "Reviewer reward is not claimed correctly"
        );
        assertEq(
            balanceAddress3AfterClaimingReward,
            balanceAddress3BeforeClaimingReward
                + reviewConfiguration.reviewerReward,
            "Reviewer reward is not claimed correctly"
        );

        // Also make sure the contracts balance is in check
        // Contract should have the same amount of funds it had before submission because submission locked funds are in total paid out to CORRECT reviewers + submitter refund
        assertEq(
            address(thriveReview).balance,
            REVIEW_CONTRACT_ALLOCATION,
            "Contract balance is not set correctly"
        );
    }

    ////////////////////////////////////////////////////////
    //            REVIEW TESTS WO WORKER UNIT             //
    ////////////////////////////////////////////////////////

    function test_300_success_CreateReviewContractWithoutWorkerUnit() public {
        // Deploy ThriveReview with no work unit
        address thriveReviewAddressWoWorkUnit = thriveReviewFactory
            .createReviewContract{value: REVIEW_CONTRACT_ALLOCATION}(
            reviewConfiguration, address(this)
        );

        ThriveReview thriveReviewWithoutWorkUnit =
            ThriveReview(payable(thriveReviewAddressWoWorkUnit));

        // Assert storage variables are initialized properly
        assertEq(
            address(thriveReviewWithoutWorkUnit.workerUnitAddress()),
            address(0),
            "WorkUnit address is not set correctly"
        );
    }

    function test_301_success_ReviewContractShouldNotRevertWhenFinalizingSubmissionWithoutWorkUnit(
    ) public {
        // Deploy ThriveReview with no work unit
        address thriveReviewAddressWoWorkUnit = thriveReviewFactory
            .createReviewContract{value: REVIEW_CONTRACT_ALLOCATION}(
            reviewConfiguration, address(this)
        );

        ThriveReview thriveReviewWithoutWorkUnit =
            ThriveReview(payable(thriveReviewAddressWoWorkUnit));

        // Create a submission
        thriveReviewWithoutWorkUnit.createSubmission{
            value: SUBMITTER_LOCKED_FUNDS
        }(submission);

        // Commit to review
        thriveReviewWithoutWorkUnit.commitToReview(0);

        // Create a review
        thriveReviewWithoutWorkUnit.submitReview(review);

        // Commit to review
        vm.prank(address(0x1));
        thriveReviewWithoutWorkUnit.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        review.id = 1;
        thriveReviewWithoutWorkUnit.submitReview(review);

        // Commit to review
        vm.prank(address(0x2));
        thriveReviewWithoutWorkUnit.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        review.id = 2;
        thriveReviewWithoutWorkUnit.submitReview(review);

        // Check that the submission is finalized
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReviewWithoutWorkUnit.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status is not set correctly"
        );
    }

    ////////////////////////////////////////////////////////
    //     FUNDS MANAGEMENT AND JUDGING WITH BADGE        //
    ////////////////////////////////////////////////////////

    function test_400_success_RetrieveFundsAsOwner() public {
        uint256 balanceBefore = address(this).balance;

        vm.warp(reviewConfiguration.submissionDeadline + 1);

        thriveReview.retrieveFundsByOwner();

        uint256 balanceAfter = address(this).balance;

        assertEq(
            balanceAfter,
            balanceBefore + REVIEW_CONTRACT_ALLOCATION,
            "Owner should be able to retrieve funds"
        );
    }

    function test_401_revert_FailToRetrieveFundsAsNonOwner() public {
        vm.prank(randomUser);
        vm.expectRevert();
        thriveReview.retrieveFundsByOwner();
    }

    function test_402_success_ReachDecisionOnSubmissionAsBadgeAfterMaxReviews()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        review.id = 1;
        thriveReview.submitReview(review);

        // Make following reviews REJECTED
        review.decision = IThriveReview.Decision.REJECTED;

        // Commit to review
        vm.prank(address(0x3));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x3));
        review.id = 2;
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x4));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x4));
        review.id = 3;
        thriveReview.submitReview(review);

        // Check that the submission is still pending because there is no consensus on decision
        IThriveReview.Decision decision = thriveReview.getSubmissionDecision(0);
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.NONE),
            "Submission status is not set correctly"
        );
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.PENDING),
            "Submission status is not set correctly"
        );

        // Finalize this submission as a judge badge
        thriveReview.reachDecisionOnSubmissionAsJudge(
            0, IThriveReview.Decision.ACCEPTED, ""
        );

        // Check that the submission is still pending because there is no consensus on decision
        decision = thriveReview.getSubmissionDecision(0);
        submissionStatus = thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.ACCEPTED),
            "Submission status is not set correctly"
        );
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status is not set correctly"
        );
    }

    function test_403_success_CorrectReviewersArePaidOutOnBadgeSubmissionFinalization(
    ) public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.submitReview(review);

        // Change the users decision to REJECTED
        review.decision = IThriveReview.Decision.REJECTED;
        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        review.id = 1;
        thriveReview.submitReview(review);

        // Users balances before distributing reviewer rewards
        uint256 balanceAddress1BeforeClaimingReward = address(0x1).balance;
        uint256 balanceAddress2BeforeClaimingReward = address(0x2).balance;

        vm.warp(
            currentBlockTimestamp + reviewConfiguration.reviewDeadlinePeriod + 1
        );
        thriveReview.reachDecisionOnSubmissionAsJudge(
            0, IThriveReview.Decision.REJECTED, ""
        );

        // Go to after dispute deadline
        vm.warp(block.timestamp + 2 days + 1);

        // Distribute rewards
        thriveReview.distributePayoutsForNonDisputedSubmission(0);

        // Users balances after distributing reviewer rewards
        uint256 balanceAddress1AfterClaimingReward = address(0x1).balance;
        uint256 balanceAddress2AfterClaimingReward = address(0x2).balance;

        // Make sure that the reviewer rewards are distributed correctly
        assertEq(
            balanceAddress1AfterClaimingReward,
            balanceAddress1BeforeClaimingReward,
            "Reviewer reward is not claimed correctly"
        );
        assertEq(
            balanceAddress2AfterClaimingReward,
            balanceAddress2BeforeClaimingReward
                + reviewConfiguration.reviewerReward,
            "Reviewer reward is not claimed correctly"
        );
    }

    function test_404_success_ReachDecisionOnSubmissionAsBadgeAfterReviewDeadline(
    ) public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        review.id = 1;
        thriveReview.submitReview(review);

        // Go to right after the review deadline
        vm.warp(
            currentBlockTimestamp + reviewConfiguration.reviewDeadlinePeriod + 1
        );

        // Finalize this submission as a judge badge
        thriveReview.reachDecisionOnSubmissionAsJudge(
            0, IThriveReview.Decision.ACCEPTED, ""
        );

        // Check that the submission is still pending because there is no consensus on decision
        IThriveReview.Decision decision = thriveReview.getSubmissionDecision(0);
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.ACCEPTED),
            "Submission status is not set correctly"
        );
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status is not set correctly"
        );
    }

    function test_405_revert_FailToReachDecisionOnSubmissionAsBadgeBeforeDeadlineWithoutMaxReviews(
    ) public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        review.id = 1;
        thriveReview.submitReview(review);

        // Revert on finalizing the submission
        vm.expectRevert(
            "Submission has not reached requirements for a final decision as badge"
        );
        thriveReview.reachDecisionOnSubmissionAsJudge(
            0, IThriveReview.Decision.ACCEPTED, ""
        );
    }

    function test_406_revert_FailToReachDecisionOnSubmissionAsBadgeWithNoProperDecision(
    ) public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        review.id = 1;
        thriveReview.submitReview(review);

        // Go to right after the review deadline
        vm.warp(
            currentBlockTimestamp + reviewConfiguration.reviewDeadlinePeriod + 1
        );

        // Revert to finalize the submission with no proper decision
        vm.expectRevert("Decision must be either 'ACCEPTED' or 'REJECTED'");
        thriveReview.reachDecisionOnSubmissionAsJudge(
            0, IThriveReview.Decision.NONE, ""
        );
    }

    function test_407_revert_FailToReachDecisionAsBadgeOnNonPendingSubmission()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        review.id = 1;
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x3));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x3));
        review.id = 2;
        thriveReview.submitReview(review);

        // Check that the submission is still finalized
        IThriveReview.Decision decision = thriveReview.getSubmissionDecision(0);
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.ACCEPTED),
            "Submission status is not set correctly"
        );
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status is not set correctly"
        );

        vm.expectRevert("Submission is not in 'PENDING' status");
        thriveReview.reachDecisionOnSubmissionAsJudge(
            0, IThriveReview.Decision.ACCEPTED, ""
        );
    }

    function test_408_success_FailedDistributionManualClaim() public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        review.id = 1;
        thriveReview.submitReview(review);

        // Now review as a contract account
        FailedDistributionExampleContract failedDistributionExampleContract =
            new FailedDistributionExampleContract(thriveReview);

        // Contrat balance before submission finalization
        uint256 balanceBeforeClaimingReward =
            address(failedDistributionExampleContract).balance;

        // Commit to review and create review
        review.id = 2;
        failedDistributionExampleContract.review(0, review);

        // Check that the submission is finalized
        IThriveReview.Decision decision = thriveReview.getSubmissionDecision(0);
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.ACCEPTED),
            "Submission decision is not set correctly"
        );
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status is not set correctly"
        );

        // Go to after dispute deadline
        vm.warp(currentBlockTimestamp + 2 days + 1);

        // Distribute rewards
        thriveReview.distributePayoutsForNonDisputedSubmission(0);

        // Contract balance after submission finalization
        uint256 balanceAfterClaimingReward =
            address(failedDistributionExampleContract).balance;

        // Assert balance after rewards distribution and submission finalization
        // These balances should be the same since distribution to the contract should have failed.
        assertEq(
            balanceAfterClaimingReward,
            balanceBeforeClaimingReward,
            "Distribution to contract should have failed"
        );

        // Assert user has funds eligible for claiming
        assertEq(
            thriveReview.failedDistributionAmounts(
                address(failedDistributionExampleContract)
            ),
            reviewConfiguration.reviewerReward,
            "User should have funds to claim"
        );

        // Claim the failed distribution amount
        failedDistributionExampleContract.claimFailedDistributionFunds();

        // Assert that the user has claimed the funds
        assertEq(
            thriveReview.failedDistributionAmounts(
                address(failedDistributionExampleContract)
            ),
            0,
            "User should have claimed the funds"
        );

        // Assert that the user has received the funds
        assertEq(
            address(failedDistributionExampleContract).balance,
            balanceBeforeClaimingReward + reviewConfiguration.reviewerReward,
            "User should have received the funds"
        );
    }

    ////////////////////////////////////////////////////////
    //              DISPUTE FUNCTIONALITY                 //
    ////////////////////////////////////////////////////////

    function test_500_revert_FailToRaiseDisputeOnNonFinalizedSubmission()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        review.id = 1;
        thriveReview.submitReview(review);

        // Check that the submission is still pending
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.PENDING),
            "Submission status is not set correctly"
        );

        vm.expectRevert("Submission is not in 'FINALIZED' status");
        thriveReview.raiseDisputeOnSubmission(0, "");
    }

    function test_501_revert_FailToRaiseDisputeAfterDisputeDeadlinePasses()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        review.id = 1;
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        review.id = 2;
        thriveReview.submitReview(review);

        // Check that the submission is finalized
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status is not set correctly"
        );

        // Go to after dispute deadline
        vm.warp(currentBlockTimestamp + 2 days + 1);

        vm.expectRevert("Dispute deadline has passed");
        thriveReview.raiseDisputeOnSubmission(0, "");
    }

    function test_502_revert_FailToRaiseDisputeIfNotInvolvedInSubmission()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        review.id = 1;
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        review.id = 2;
        thriveReview.submitReview(review);

        // Check that the submission is finalized
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status is not set correctly"
        );

        vm.expectRevert("User is not involved in the submission");
        vm.prank(address(0x3));
        thriveReview.raiseDisputeOnSubmission(0, "");
    }

    function test_503_success_RaiseDisputeOnSubmission() public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        review.id = 1;
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x3));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x3));
        review.id = 2;
        thriveReview.submitReview(review);

        // Check that the submission is finalized
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status is not set correctly"
        );

        // Raise dispute
        thriveReview.raiseDisputeOnSubmission(0, "");

        // Check that the submission is disputed
        IThriveReview.SubmissionStatus submissionStatusAfterDispute =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatusAfterDispute),
            uint256(IThriveReview.SubmissionStatus.DISPUTED),
            "Submission status is not set correctly"
        );
    }

    function test_504_revert_FailToResolveDisputeOnNonDisputedSubmission()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        review.id = 1;
        thriveReview.submitReview(review);

        // Check that the submission is still pending
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.PENDING),
            "Submission status is not set correctly"
        );

        vm.expectRevert("Submission is not in 'DISPUTED' status");
        thriveReview.resolveDisputeOnSubmission(
            0, IThriveReview.Decision.ACCEPTED, ""
        );
    }

    function test_505_success_ResolveDisputeAndSuccessfullyDistributeRewards()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        review.id = 1;
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x3));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x3));
        review.id = 2;
        review.decision = IThriveReview.Decision.REJECTED;
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x4));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x4));
        review.id = 3;
        review.decision = IThriveReview.Decision.ACCEPTED;
        thriveReview.submitReview(review);

        // User 0x3 balance before dispute resolution
        uint256 balanceAddress3BeforeDispute = address(0x3).balance;

        // Check that the submission is finalized
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status is not set correctly"
        );

        // Raise dispute
        thriveReview.raiseDisputeOnSubmission(0, "");

        // Check that the submission is disputed
        IThriveReview.SubmissionStatus submissionStatusAfterDispute =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatusAfterDispute),
            uint256(IThriveReview.SubmissionStatus.DISPUTED),
            "Submission status is not set correctly"
        );

        // Resolve dispute
        thriveReview.resolveDisputeOnSubmission(
            0, IThriveReview.Decision.REJECTED, ""
        );

        // Check that the submission is resolved
        IThriveReview.SubmissionStatus submissionStatusAfterResolve =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatusAfterResolve),
            uint256(IThriveReview.SubmissionStatus.PAID_OUT),
            "Submission status is not set correctly"
        );

        // Check that the submission is rejected
        IThriveReview.Decision decision = thriveReview.getSubmissionDecision(0);
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.REJECTED),
            "Submission decision is not set correctly"
        );

        // Check address 0x3 balance after dispute resolution
        uint256 balanceAddress3AfterDispute = address(0x3).balance;

        // Check that the reviewer who made the right decision is paid out
        assertEq(
            balanceAddress3AfterDispute,
            balanceAddress3BeforeDispute + reviewConfiguration.reviewerReward,
            "Reviewer balance is not set correctly"
        );
    }

    function test_506_revert_FailToCancelNonDisputedSubmission() public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        review.id = 1;
        thriveReview.submitReview(review);

        // Check that the submission is still pending
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.PENDING),
            "Submission status is not set correctly"
        );

        vm.expectRevert("Submission is not in 'DISPUTED' status");
        thriveReview.cancelDisputeOnSubmission(0);
    }

    function test_507_revert_FailToCancelDisputeBeforeTime() public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        review.id = 1;
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x3));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x3));
        review.id = 2;
        thriveReview.submitReview(review);

        // Raise dispute
        thriveReview.raiseDisputeOnSubmission(0, "");

        // Check that the submission is disputed
        IThriveReview.SubmissionStatus submissionStatusAfterDispute =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatusAfterDispute),
            uint256(IThriveReview.SubmissionStatus.DISPUTED),
            "Submission status is not set correctly"
        );

        // Go to before dispute deadline
        vm.warp(currentBlockTimestamp + 3 days - 1);

        vm.expectRevert("Dispute deadline has not passed");
        thriveReview.cancelDisputeOnSubmission(0);
    }

    function test_508_success_CancelDisputeOnSubmissionAndDistributeRewards()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        review.id = 1;
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x3));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x3));
        review.id = 2;
        thriveReview.submitReview(review);

        // Raise dispute
        thriveReview.raiseDisputeOnSubmission(0, "");

        // Check that the submission is disputed
        IThriveReview.SubmissionStatus submissionStatusAfterDispute =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatusAfterDispute),
            uint256(IThriveReview.SubmissionStatus.DISPUTED),
            "Submission status is not set correctly"
        );

        // Go to after dispute time + buffer
        vm.warp(currentBlockTimestamp + 3 days + 1);

        // User 0x3 balance before dispute resolution
        uint256 balanceAddress3BeforeDispute = address(0x3).balance;

        // Cancel dispute
        thriveReview.cancelDisputeOnSubmission(0);

        // Check that the submission is resolved
        IThriveReview.SubmissionStatus submissionStatusAfterResolve =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatusAfterResolve),
            uint256(IThriveReview.SubmissionStatus.PAID_OUT),
            "Submission status is not set correctly"
        );

        // Check that the submission is accepted
        IThriveReview.Decision decision = thriveReview.getSubmissionDecision(0);
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.ACCEPTED),
            "Submission decision is not set correctly"
        );

        // Check address 0x3 balance after dispute resolution
        uint256 balanceAddress3AfterDispute = address(0x3).balance;

        // Check that the reviewer who made the right decision is paid out
        assertEq(
            balanceAddress3AfterDispute,
            balanceAddress3BeforeDispute + reviewConfiguration.reviewerReward,
            "Reviewer balance is not set correctly"
        );
    }

    function test_509_revert_FailToDistributePayoutsToNonFinalizedSubmissions()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        review.id = 1;
        thriveReview.submitReview(review);

        // Check that the submission is still pending
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.PENDING),
            "Submission status is not set correctly"
        );

        // Go to after dispute deadline
        vm.expectRevert("Submission is not in 'FINALIZED' status");
        uint256[] memory submissionIds = new uint256[](1);
        submissionIds[0] = 0;
        thriveReview.distributePayoutsForNonDisputedSubmissions(submissionIds);
    }

    function test_510_revert_FailToDistributePayoutsToFinalizedSubmissionsBeforeDisputeDeadline(
    ) public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        review.id = 1;
        thriveReview.submitReview(review);

        // Go to right after the review deadline
        vm.warp(
            currentBlockTimestamp + reviewConfiguration.reviewDeadlinePeriod + 1
        );

        // Finalize this submission as a judge badge
        thriveReview.reachDecisionOnSubmissionAsJudge(
            0, IThriveReview.Decision.ACCEPTED, ""
        );

        // Check that the submission is still pending because there is no consensus on decision
        IThriveReview.Decision decision = thriveReview.getSubmissionDecision(0);
        IThriveReview.SubmissionStatus submissionStatus =
            thriveReview.getSubmissionStatus(0);
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.ACCEPTED),
            "Submission status is not set correctly"
        );
        assertEq(
            uint256(submissionStatus),
            uint256(IThriveReview.SubmissionStatus.FINALIZED),
            "Submission status is not set correctly"
        );

        // Go to before dispute deadline
        vm.warp(block.timestamp + 2 days - 1);

        vm.expectRevert("Dispute deadline has not passed");
        thriveReview.distributePayoutsForNonDisputedSubmission(0);
    }

    function test_511_success_DistributePayoutToFinalizedNonDisputedSubmission()
        public
    {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.submitReview(review);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        review.id = 1;
        thriveReview.submitReview(review);

        // Balance of address 0x1 before getting reward
        uint256 balanceAddress1BeforeClaimingReward = address(0x1).balance;

        // Go to right after the review deadline
        vm.warp(
            currentBlockTimestamp + reviewConfiguration.reviewDeadlinePeriod + 1
        );

        // Finalize this submission as a judge badge
        thriveReview.reachDecisionOnSubmissionAsJudge(
            0, IThriveReview.Decision.ACCEPTED, ""
        );

        // Go to after dispute deadline
        vm.warp(block.timestamp + 2 days + 1);

        // Distribute rewards
        thriveReview.distributePayoutsForNonDisputedSubmission(0);

        // Check payout to correct reviewers
        uint256 balanceAddress1AfterClaimingReward = address(0x1).balance;

        // Make sure that the reviewer rewards are distributed correctly
        assertEq(
            balanceAddress1AfterClaimingReward,
            balanceAddress1BeforeClaimingReward
                + reviewConfiguration.reviewerReward,
            "Reviewer reward is not claimed correctly"
        );
    }

    function test_512_success_DisputeStorageObjectCorrectlyStored() public {
        // Create a submission
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission);

        // Go to after review deadline so judge can make the decision
        vm.warp(
            currentBlockTimestamp + reviewConfiguration.reviewDeadlinePeriod + 1
        );

        // Finalize this submission as a judge badge
        thriveReview.reachDecisionOnSubmissionAsJudge(
            0,
            IThriveReview.Decision.ACCEPTED,
            "I think this submission should be accepted"
        );

        // Get submission decision
        IThriveReview.Decision decision = thriveReview.getSubmissionDecision(0);
        assertEq(
            uint256(decision),
            uint256(IThriveReview.Decision.ACCEPTED),
            "Submission decision is not set correctly"
        );

        // Raise dispute
        thriveReview.raiseDisputeOnSubmission(
            0, "I think this submission should be rejected"
        );

        // Resolve dispute
        thriveReview.resolveDisputeOnSubmission(
            0,
            IThriveReview.Decision.REJECTED,
            "I think this submission should NOT be rejected"
        );

        // Get dispute object
        (
            uint256 submissionId,
            address disputer,
            address resolver,
            string memory disputeMetadata,
            string memory disputeResolutionMetadata
        ) = thriveReview.disputes(0);

        // Assert that the dispute object is stored correctly
        assertEq(submissionId, 0, "Submission ID is not set correctly");
        assertEq(
            disputer, address(this), "Disputer address is not set correctly"
        );
        assertEq(
            resolver, address(this), "Resolver address is not set correctly"
        );
        assertEq(
            disputeMetadata,
            "I think this submission should be rejected",
            "Dispute metadata is not set correctly"
        );
        assertEq(
            disputeResolutionMetadata,
            "I think this submission should NOT be rejected",
            "Dispute resolution metadata is not set correctly"
        );
    }

    receive() external payable {}
}

// This contract is written as an example of how a malicious address may act and try to fail the distribution of funds
// We also test that in case of such failed distribution, the address can manually claim funds.
contract FailedDistributionExampleContract {
    ThriveReview public thriveReview;

    uint256 counter = 0;

    constructor(ThriveReview _thriveReview) {
        thriveReview = _thriveReview;
    }

    function review(
        uint256 submissionId_,
        IThriveReview.Review calldata review_
    ) public {
        thriveReview.commitToReview(submissionId_);
        thriveReview.submitReview(review_);
    }

    function claimFailedDistributionFunds() public {
        counter++;
        thriveReview.claimFailedDistributionFunds();
    }

    receive() external payable {
        if (counter == 0) {
            revert();
        }
    }
}
