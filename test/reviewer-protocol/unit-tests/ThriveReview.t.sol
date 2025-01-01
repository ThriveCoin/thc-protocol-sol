// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import "../../../src/ThriveWorkerUnitFactory.sol";
import "../../../src/reviewer-protocol/ThriveReviewFactory.sol";
import "../../../src/reviewer-protocol/ThriveReview.sol";

import "./BasicTestConfigs.t.sol";

import "openzeppelin-foundry-upgrades/Upgrades.sol";

contract ThriveReviewUnitTests is Test, BasicTestConfigs {
    using Upgrades for address;

    ThriveWorkerUnitFactory thriveWorkerUnitFactory;
    ThriveReviewFactory thriveReviewFactory;
    ThriveReview thriveReviewImplementation;

    address randomUser = address(0x1234);

    address thriveReviewFactoryAddress;

    address thriveReviewAddress;
    address thriveWorkUnitContract;

    ThriveReview thriveReview;

    function setUp() public {
        // Deploy ThriveWorkerUnitFactory
        thriveWorkerUnitFactory = new ThriveWorkerUnitFactory();

        // Deploy ThriveReview implementation
        thriveReviewImplementation = new ThriveReview();

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
        thriveReviewFactory = ThriveReviewFactory(thriveReviewFactoryAddress);

        // Create a ThriveWorkUnit and ThriveReview contract
        (thriveReviewAddress, thriveWorkUnitContract) = thriveReviewFactory
            .createWorkUnitAndReviewContract{value: 10 ether}(
            workUnitArgs, reviewConfiguration
        );

        thriveReview = ThriveReview(payable(thriveReviewAddress));
    }

    function test01_fail_ToInitializeReviewTwice() public {
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

    function test02_success_ReviewContractInitializedCorrectly() public view {
        // Assert storage variables are initialized properly
        assertEq(
            thriveReview.workUnitContractAddress(),
            thriveWorkUnitContract,
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

    // This test can be uncommented and run with: --via-ir flag
    function test03_success_ReviewConfigurationCorrectlyInitialized()
        public
        view
    {
        /*
        ///// Badges are tested in access control tests

        (address workUnit, uint256 reviewerRewardsTotalAllocation, uint256 reviewerReward, 
        uint32 agreementThreshold, uint32 maximumSubmissionsPerUser, uint32 minimumReviews, uint32 maximumSubmissions,
        uint32 maximumReviewsPerSubmission, uint32 submissionDeadline, uint32 reviewCommitmentDeadline, 
        string memory reviewMetadata, string memory submissionMetadata) = thriveReview.reviewConfiguration();

        // Assert review configuration is initialized properly
        assertEq(workUnit, thriveWorkUnitContract, "WorkUnit address is not set correctly");
        assertEq(reviewerRewardsTotalAllocation, reviewConfiguration.reviewerRewardsTotalAllocation, "reviewerRewardsTotalAllocation is not set correctly");
        assertEq(reviewerReward, reviewConfiguration.reviewerReward, "reviewerReward is not set correctly");
        assertEq(agreementThreshold, reviewConfiguration.agreementThreshold, "agreementThreshold is not set correctly");
        assertEq(maximumSubmissionsPerUser, reviewConfiguration.maximumSubmissionsPerUser, "maximumSubmissionsPerUser is not set correctly");
        assertEq(minimumReviews, reviewConfiguration.minimumReviews, "minimumReviews is not set correctly");
        assertEq(maximumSubmissions, reviewConfiguration.maximumSubmissions, "maximumSubmissions is not set correctly");
        assertEq(maximumReviewsPerSubmission, reviewConfiguration.maximumReviewsPerSubmission, "maximumReviewsPerSubmission is not set correctly");
        assertEq(submissionDeadline, reviewConfiguration.submissionDeadline, "submissionDeadline is not set correctly");
        assertEq(reviewCommitmentDeadline, reviewConfiguration.reviewCommitmentDeadline, "reviewCommitmentDeadline is not set correctly");
        assertEq(reviewMetadata, reviewConfiguration.reviewMetadata, "reviewMetadata is not set correctly");
        assertEq(submissionMetadata, reviewConfiguration.submissionMetadata, "submissionMetadata is not set correctly");
        */
    }

    function test04_fail_UserCanNotHaveMoreThanOnePendingSubmission() public {
        // Create a submission
        thriveReview.createSubmission(submission);

        vm.expectRevert("User has a pending submission");
        thriveReview.createSubmission(submission);
    }

    function test05_fail_UserCanNotHaveMoreThanMaximumSubmissionsPerUser() public {
    }

    function test06_fail_UserCanNotHaveMoreThanMaximumSubmissions() public {
    }

    function test07_fail_UserCanNotSubmitAfterDeadline() public {
        vm.warp(reviewConfiguration.submissionDeadline + 1);

        vm.expectRevert("Submission deadline has passed");
        thriveReview.createSubmission(submission);
    }
    
    function test08_success_SubmissionIsCorrectlyStored() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Get the submission
        (address contributor, string memory submissionMetadata, uint256 reviewCount, 
        uint256 acceptedReviewCount, uint256 rejectedReviewCount, IThriveReview.Decision decision, 
        IThriveReview.SubmissionStatus status) = thriveReview.submissions(0);

        // Assert submission is stored correctly
        assertEq(contributor, submission.contributor, "Contributor is not set correctly");
        assertEq(submissionMetadata, submission.submissionMetadata, "Submission metadata is not set correctly");
        assertEq(uint256(status), uint256(IThriveReview.SubmissionStatus.PENDING), "Review status is not set correctly");

        assertEq(reviewCount, 0, "Review count is not set correctly");
        assertEq(acceptedReviewCount, 0, "Accepted review count is not set correctly");
        assertEq(rejectedReviewCount, 0, "Rejected review count is not set correctly");

        assertEq(uint256(decision), uint256(IThriveReview.Decision.NONE), "Decision is not set correctly");

        // Fetch user submissions
        uint256 userSubmissionId = thriveReview.userSubmissions(address(this), 0);
        assertEq(userSubmissionId, 0, "User submissions ids are not set correctly");
    }

    function test09_success_SubmissionIsUpdated() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        submission.submissionMetadata = "Updated submission metadata";

        // Update the submission
        thriveReview.updateSubmission(submission, 0);

        // Get the submission
        (, string memory submissionMetadata, uint256 reviewCount, 
        uint256 acceptedReviewCount, uint256 rejectedReviewCount, IThriveReview.Decision decision, 
        IThriveReview.SubmissionStatus status) = thriveReview.submissions(0);

        // Assert submission is stored correctly
        assertEq(submissionMetadata, "Updated submission metadata", "Submission metadata is not set correctly");
        assertEq(uint256(status), uint256(IThriveReview.SubmissionStatus.PENDING), "Review status is not set correctly");

        assertEq(reviewCount, 0, "Review count is not set correctly");
        assertEq(acceptedReviewCount, 0, "Accepted review count is not set correctly");
        assertEq(rejectedReviewCount, 0, "Rejected review count is not set correctly");
        assertEq(uint256(decision), uint256(IThriveReview.Decision.NONE), "Decision is not set correctly");
    }

    function test10_fail_ToUpdateSubmissionAfterDeadline() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        vm.warp(reviewConfiguration.submissionDeadline + 1);

        vm.expectRevert("Submission deadline has passed");
        thriveReview.updateSubmission(submission, 0);
    }

    function test11_fail_ToUpdateSubmissionMadeByAnotherUser() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        vm.prank(randomUser);

        vm.expectRevert("Caller has not submitted this submission");
        thriveReview.updateSubmission(submission, 0);
    }

    function test12_fail_ToUpdateSubmissionThatIsNotPending() public {
    }

    function test13_success_UserCommitsToReview() public {
        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Get the review
        (uint256 id, uint256 submissionId, address reviewer, string memory reviewMetadata, uint256 deadline, IThriveReview.Decision decision, IThriveReview.ReviewStatus status) = thriveReview.reviews(0);

        // Assert review is stored correctly
        assertEq(id, 0, "Review id is not set correctly");
        assertEq(submissionId, 0, "Submission id is not set correctly");
        assertEq(reviewer, address(this), "Reviewer is not set correctly");
        assertEq(reviewMetadata, "", "Review metadata is not set correctly");
        assertEq(deadline, block.timestamp + reviewConfiguration.reviewCommitmentDeadline, "Deadline is not set correctly");
        assertEq(uint256(status), uint256(IThriveReview.ReviewStatus.COMMITED), "Review status is not set correctly");
        assertEq(uint256(decision), uint256(IThriveReview.Decision.NONE), "Decision is not set correctly");

        // Fetch user commmits to review the submission
        uint256 counterOfCommitedReviews = thriveReview.committedReviewsPerSubmissionCounter(0);
        assertEq(counterOfCommitedReviews, 1, "User review ids are not set correctly");
    }

    function test14_fail_ToCommitReviewToTheSameSubmissionTwice() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        vm.expectRevert("User has already committed to review this submission");
        thriveReview.commitToReview(0);
    }

    function test15_fail_ToCommitReviewAfterMaximumReviewsPerSubmissionReached() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);
        vm.stopPrank();

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);
        vm.stopPrank();

        // Commit to review
        vm.prank(address(0x3));
        thriveReview.commitToReview(0);
        vm.stopPrank();

        vm.expectRevert("Maximum amount of commits to review has been reached");
        thriveReview.commitToReview(0);
    }

    function test16_fail_ToCommitReviewToSubmissionThatIsNotPending() public {
    }

    function test17_fail_ToCreateReviewThatWasNotCommited() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        vm.expectRevert("User has not commited to this review");
        thriveReview.createReview(review, 0);
    }

    function test18_fail_ToCreateReviewForSubmissionThatIsNotPending() public {
    }

    function test19_fail_ToCreateReviewByNonCommittingUser() public {
        
        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Some other user commits to review
        vm.prank(randomUser);
        thriveReview.commitToReview(0);
        vm.stopPrank();

        // User can not create review commited by someone else
        vm.expectRevert("User is not the committer of this review");
        thriveReview.createReview(review, 1);
    }

    function test20_fail_ToCreateReviewAfterDeadline() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        vm.warp(block.timestamp + reviewConfiguration.reviewCommitmentDeadline + 1);

        vm.expectRevert("Review deadline has passed");
        thriveReview.createReview(review, 0);
    }

    function test21_fail_ToCreateReviewWithWrongDecision() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        review.decision = IThriveReview.Decision.NONE;

        vm.expectRevert("Review decision must be either 'ACCEPTED' or 'REJECTED'");
        thriveReview.createReview(review, 0);
    }

    function test22_success_CreateReviewAfterCommittingToIt() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.createReview(review, 0);

        // Get the review
        (uint256 id, uint256 submissionId, address reviewer, string memory reviewMetadata, uint256 deadline, IThriveReview.Decision decision, IThriveReview.ReviewStatus status) = thriveReview.reviews(0);

        // Assert review is stored correctly
        assertEq(id, 0, "Review id is not set correctly");
        assertEq(submissionId, 0, "Submission id is not set correctly");
        assertEq(reviewer, address(this), "Reviewer is not set correctly");
        assertEq(reviewMetadata, "reviewMetadata", "Review metadata is not set correctly");
        assertEq(deadline, block.timestamp + reviewConfiguration.reviewCommitmentDeadline, "Deadline is not set correctly");
        assertEq(uint256(status), uint256(IThriveReview.ReviewStatus.DONE), "Review status is not set correctly");
        assertEq(uint256(decision), uint256(IThriveReview.Decision.ACCEPTED), "Decision is not set correctly");

        // Fetch user reviews
        uint256 userReviewId = thriveReview.userReviews(address(this), 0);
        assertEq(userReviewId, 0, "User reviews ids are not set correctly");

        uint256 reviewsPerSubmissionCounter = thriveReview.reviewsPerSubmissionCounter(0);
        assertEq(reviewsPerSubmissionCounter, 1, "Reviews per submission counter is not set correctly");

        // Fetch submission after the review
        (, , uint256 reviewCount, uint256 acceptedReviewCount, uint256 rejectedReviewCount, IThriveReview.Decision submissionDecision, IThriveReview.SubmissionStatus submissionStatus) = thriveReview.submissions(0);
        assertEq(reviewCount, 1, "Review count is not set correctly");
        assertEq(acceptedReviewCount, 1, "Accepted review count is not set correctly");
        assertEq(rejectedReviewCount, 0, "Rejected review count is not set correctly");
        assertEq(uint256(submissionDecision), uint256(IThriveReview.Decision.NONE), "Decision is not set correctly");
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.PENDING), "Submission status is not set correctly");
    }

    function test23_success_DeletePendingReviews() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Commit to another review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Commit to another review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        uint256 committedReviewsPerSubmissionCounter = thriveReview.committedReviewsPerSubmissionCounter(0);
        assertEq(committedReviewsPerSubmissionCounter, 3, "Committed reviews per submission counter is not set correctly");

        bool userCommitedToReview = thriveReview.userCommitedToReview(address(this), 0);
        assertEq(userCommitedToReview, true, "User has not commited to review");

        vm.warp(block.timestamp + reviewConfiguration.reviewCommitmentDeadline + 1);

        // Delete pending reviews
        uint256[] memory reviewIds = new uint256[](3);
        reviewIds[0] = 0;
        reviewIds[1] = 1;
        reviewIds[2] = 2;
        thriveReview.deletePendingReviews(reviewIds);

        // Get the review
        (, , , , , , IThriveReview.ReviewStatus status) = thriveReview.reviews(0);

        // Assert review is deleted
        assertEq(uint256(status), uint256(IThriveReview.ReviewStatus.NONE), "Review status is not set correctly");

        // Get the review
        (, , , , , , status) = thriveReview.reviews(1);

        // Assert review is deleted
        assertEq(uint256(status), uint256(IThriveReview.ReviewStatus.NONE), "Review status is not set correctly");

        // Get the review
        (, , , , , , status) = thriveReview.reviews(2);

        // Assert review is deleted
        assertEq(uint256(status), uint256(IThriveReview.ReviewStatus.NONE), "Review status is not set correctly");

        committedReviewsPerSubmissionCounter = thriveReview.committedReviewsPerSubmissionCounter(0);
        assertEq(committedReviewsPerSubmissionCounter, 0, "Committed reviews per submission counter is not set correctly");

        userCommitedToReview = thriveReview.userCommitedToReview(address(this), 0);
        assertEq(userCommitedToReview, false, "Storage updated incorrectly");

    }

    function test24_fail_ToDeleteNonCommittedReview() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Commit to another review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create review by address(0x1)
        thriveReview.createReview(review, 0);
        vm.stopPrank();

        vm.warp(block.timestamp + reviewConfiguration.reviewCommitmentDeadline + 1);

        // Delete pending reviews
        uint256[] memory reviewIds = new uint256[](2);
        reviewIds[0] = 0;
        reviewIds[1] = 1;

        vm.expectRevert("Review is not in 'COMMITED' status");
        thriveReview.deletePendingReviews(reviewIds);
    }

    function test25_fail_ToDeleteNonExpiredCommittedReview() public {

        // Create a submission
        thriveReview.createSubmission(submission);

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

    // reachDecisionOnSubmission and reachDecisionOnSubmissionAsBadge

    // claimReviewerRewards and claimReviewerReward

    // retrieveFunds (onlyOwner)

}
