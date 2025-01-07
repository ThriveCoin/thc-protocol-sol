// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import "../../../src/ThriveWorkerUnitFactory.sol";
import "../../../src/reviewer-protocol/ThriveReviewFactory.sol";
import "../../../src/reviewer-protocol/ThriveReview.sol";
import "../../../src/interface/IThriveWorkerUnit.sol";

import "./BasicTestConfigs.t.sol";


import {MockERC20} from "test/mock/MockERC20.sol";


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
        thriveReviewFactory = ThriveReviewFactory(thriveReviewFactoryAddress);

        // Create a ThriveWorkUnit and ThriveReview contract
        (thriveReviewAddress, thriveWorkerUnitAddress) = thriveReviewFactory
            .createWorkUnitAndReviewContract{value: 10 ether}(
            workUnitArgs, reviewConfiguration
        );

        thriveReview = ThriveReview(payable(thriveReviewAddress));

        mockToken.approve(address(thriveWorkerUnitAddress), 1_000 ether);

        IThriveWorkerUnit(thriveWorkerUnitAddress).initialize{value: 100 ether}();


        // Add required badge to ThriveWorkerUnit
        IThriveWorkerUnit(thriveWorkerUnitAddress).addRequiredBadge(keccak256("TestBadge"));

        vm.mockCall(
            badgeQueryContractAddress,
            abi.encodeWithSelector(IBadgeQuery.hasBadge.selector),
            abi.encode(true)
        );
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

    function test05_fail_UserCanNotHaveMoreThanOneAcceptedSubmission() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        /**
         * JUDGE ON FIRST SUBMISSION - ACCEPT IT
         */

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.createReview(review, 0);


        vm.prank(address(0x1));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x1));
        // Create a review
        thriveReview.createReview(review, 1);


        vm.prank(address(0x2));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x2));
        // Create a review
        thriveReview.createReview(review, 2);


        // Check that the submission is finalized
        (, , , , , IThriveReview.Decision decision, IThriveReview.SubmissionStatus submissionStatus) = thriveReview.submissions(0);
        assertEq(uint256(decision), uint256(IThriveReview.Decision.ACCEPTED), "Submission status is not set correctly"); 
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.FINALIZED), "Submission status is not set correctly");

        // Create a submission
        vm.expectRevert("User already has an accepted submission");
        thriveReview.createSubmission(submission);

    }


    function test06_fail_UserCanNotHaveMoreThanMaximumSubmissionsPerUser() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        /**
         * JUDGE ON FIRST SUBMISSION - REJECT IT
         */

        // Commit to review
        thriveReview.commitToReview(0);

        review.decision = IThriveReview.Decision.REJECTED;
        // Create a review
        thriveReview.createReview(review, 0);


        vm.prank(address(0x1));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x1));
        // Create a review
        thriveReview.createReview(review, 1);


        vm.prank(address(0x2));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x2));
        // Create a review
        thriveReview.createReview(review, 2);


        // Check that the submission is finalized
        (, , , , , , IThriveReview.SubmissionStatus submissionStatus) = thriveReview.submissions(0);
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.FINALIZED), "Submission status is not set correctly");



        // Create another submission
        thriveReview.createSubmission(submission);


        /**
         * JUDGE ON SECOND SUBMISSION - REJECT IT
         */

        // Commit to review
        thriveReview.commitToReview(1);

        // Create a review
        thriveReview.createReview(review, 3);


        vm.prank(address(0x1));
        // Commit to a review
        thriveReview.commitToReview(1);

        vm.prank(address(0x1));
        // Create a review
        thriveReview.createReview(review, 4);


        vm.prank(address(0x2));
        // Commit to a review
        thriveReview.commitToReview(1);

        vm.prank(address(0x2));
        // Create a review
        thriveReview.createReview(review, 5);

        // Check that the submission is finalized
        (, , , , , , submissionStatus) = thriveReview.submissions(0);
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.FINALIZED), "Submission status is not set correctly");

        // Try to create another submission, but can not because the user has reached the maximum submissions
        vm.expectRevert("User has reached the maximum number of submissions");
        thriveReview.createSubmission(submission);

    }


    function test07_fail_UserCanNotSubmitWhenThereIsMaximumSubmissions() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Create a submission
        vm.prank(address(0x1));
        thriveReview.createSubmission(submission);

        // Create a submission
        vm.prank(address(0x2));
        thriveReview.createSubmission(submission);

        // Create a submission
        vm.prank(address(0x3));
        thriveReview.createSubmission(submission);

        // Create a submission
        vm.prank(address(0x4));
        thriveReview.createSubmission(submission);

        // Create a submission
        vm.prank(address(0x5));
        vm.expectRevert("Maximum amount of submissions has been reached");
        thriveReview.createSubmission(submission);

    }


    function test08_fail_UserCanNotSubmitAfterDeadline() public {
        vm.warp(reviewConfiguration.submissionDeadline + 1);

        vm.expectRevert("Submission deadline has passed");
        thriveReview.createSubmission(submission);
    }
    

    function test09_success_SubmissionIsCorrectlyStored() public {

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


    function test10_success_SubmissionIsUpdated() public {

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


    function test11_fail_ToUpdateSubmissionAfterDeadline() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        vm.warp(reviewConfiguration.submissionDeadline + 1);

        vm.expectRevert("Submission deadline has passed");
        thriveReview.updateSubmission(submission, 0);
    }


    function test12_fail_ToUpdateSubmissionMadeByAnotherUser() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        vm.prank(randomUser);

        vm.expectRevert("Caller has not submitted this submission");
        thriveReview.updateSubmission(submission, 0);
    }


    function test13_fail_ToUpdateSubmissionThatIsNotPending() public {
        
        // Create submission
        thriveReview.createSubmission(submission);

        /**
         * JUDGE ON SUBMISSION
         */

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.createReview(review, 0);


        vm.prank(address(0x1));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x1));
        // Create a review
        thriveReview.createReview(review, 1);


        vm.prank(address(0x2));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x2));
        // Create a review
        thriveReview.createReview(review, 2);

        // Check that the submission is finalized
        (, , , , , , IThriveReview.SubmissionStatus submissionStatus) = thriveReview.submissions(0);
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.FINALIZED), "Submission status is not set correctly");

        vm.expectRevert("Submission is not in 'PENDING' status");
        thriveReview.updateSubmission(submission, 0);

    }


    function test14_success_UserCommitsToReview() public {
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


    function test15_fail_ToCommitReviewToTheSameSubmissionTwice() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        vm.expectRevert("User has already committed to review this submission");
        thriveReview.commitToReview(0);
    }

    function test16x_fail_ToCommitReviewAfterReviewDeadline() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        vm.warp(block.timestamp + reviewConfiguration.reviewDeadline + 1);

        vm.expectRevert("Review deadline has passed");
        thriveReview.commitToReview(0);
    }

    function test16_fail_ToCommitReviewAfterMaximumReviewsPerSubmissionReached() public {

        // Create a submission
        thriveReview.createSubmission(submission);

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


    function test17_fail_ToCommitReviewToSubmissionThatIsNotPending() public {

        // Create submission
        thriveReview.createSubmission(submission);

        /**
         * JUDGE ON SUBMISSION
         */

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.createReview(review, 0);


        vm.prank(address(0x1));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x1));
        // Create a review
        thriveReview.createReview(review, 1);


        vm.prank(address(0x2));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x2));
        // Create a review
        thriveReview.createReview(review, 2);

        // Check that the submission is finalized
        (, , , , , , IThriveReview.SubmissionStatus submissionStatus) = thriveReview.submissions(0);
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.FINALIZED), "Submission status is not set correctly");

        vm.expectRevert("Submission is not in 'PENDING' status");
        thriveReview.commitToReview(0);

    }


    function test18_fail_ToCreateReviewThatWasNotCommited() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        vm.expectRevert("User has not commited to this review");
        thriveReview.createReview(review, 0);
    }


    function test19_fail_ToCreateReviewForSubmissionThatIsNotPending() public {
        
        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.createReview(review, 0);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        thriveReview.createReview(review, 1);


        // Commit to review
        vm.prank(address(0x3));
        thriveReview.commitToReview(0);
        // This review will not be created, and later rejected because the submission judging has been finalized

        // Commit to review
        vm.prank(address(0x4));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x4));
        thriveReview.createReview(review, 3);

        // Now submission has enough reviews to be judged on
        // Check that the submission is finalized
        (, , , , , , IThriveReview.SubmissionStatus submissionStatus) = thriveReview.submissions(0);
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.FINALIZED), "Submission status is not set correctly");

        // Can not create review because the submission has already been judged on.
        vm.prank(address(0x3));
        vm.expectRevert("Submission is not in 'PENDING' status");
        thriveReview.createReview(review, 2);

    }


    function test20_fail_ToCreateReviewByNonCommittingUser() public {
        
        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Some other user commits to review
        vm.prank(randomUser);
        thriveReview.commitToReview(0);

        // User can not create review commited by someone else
        vm.expectRevert("User is not the committer of this review");
        thriveReview.createReview(review, 1);
    }


    function test21_fail_ToCreateReviewAfterCommitmentDeadline() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        vm.warp(block.timestamp + reviewConfiguration.reviewCommitmentDeadline + 1);

        vm.expectRevert("Review commitment deadline has passed");
        thriveReview.createReview(review, 0);
    }

    function test21x_fail_ToCreateReviewAfterReviewDeadline() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Go to right before the review deadline to commit
        vm.warp(reviewConfiguration.reviewDeadline - 1);

        // Commit to review
        thriveReview.commitToReview(0);

        // Go to right after the review deadline to create review
        vm.warp(reviewConfiguration.reviewDeadline + 1);

        vm.expectRevert("Review deadline has passed");
        thriveReview.createReview(review, 0);
    }


    function test22_fail_ToCreateReviewWithWrongDecision() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        review.decision = IThriveReview.Decision.NONE;

        vm.expectRevert("Review decision must be either 'ACCEPTED' or 'REJECTED'");
        thriveReview.createReview(review, 0);
    }


    function test23_success_CreateReviewAfterCommittingToIt() public {

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


    function test24_success_DeletePendingReviews() public {

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


    function test25_fail_ToDeleteNonCommittedReview() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Commit to another review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);
        // Create review by address(0x1)
        thriveReview.createReview(review, 0);


        vm.warp(block.timestamp + reviewConfiguration.reviewCommitmentDeadline + 1);

        // Delete pending reviews
        uint256[] memory reviewIds = new uint256[](2);
        reviewIds[0] = 0;
        reviewIds[1] = 1;

        vm.expectRevert("Review is not in 'COMMITED' status");
        thriveReview.deletePendingReviews(reviewIds);
    }


    function test26_fail_ToDeleteNonExpiredCommittedReview() public {

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
    
    /*
    function test27_success_ClaimReviewerRewardForCorrectJudgement() public {
        
        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.createReview(review, 0);


        vm.prank(address(0x1));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x1));
        // Create a review
        thriveReview.createReview(review, 1);


        vm.prank(address(0x2));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x2));
        // Create a review
        thriveReview.createReview(review, 2);


        // Check that the submission is finalized
        (, , , , , , IThriveReview.SubmissionStatus submissionStatus) = thriveReview.submissions(0);
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.FINALIZED), "Submission status is not set correctly");

        // Assert balance before claiming
        uint256 balanceBeforeClaimingReward = address(this).balance;

        // Claim reviewer reward
        thriveReview.claimReviewerReward(0);

        // Assert balance after claiming
        uint256 balanceAfterClaimingReward = address(this).balance;

        assertEq(balanceAfterClaimingReward, balanceBeforeClaimingReward + reviewConfiguration.reviewerReward, "Reviewer reward is not claimed correctly");

        // Get the review
        (, , , , , , IThriveReview.ReviewStatus status) = thriveReview.reviews(0);

        // Assert review is deleted
        assertEq(uint256(status), uint256(IThriveReview.ReviewStatus.DONE), "Review status is not set correctly");
    }


    function test28_fail_ToClaimReviewerRewardForIncorrectJudgement() public {
        
        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.createReview(review, 0);

        // Commit to a review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        review.decision = IThriveReview.Decision.REJECTED;
        vm.prank(address(0x1));
        thriveReview.createReview(review, 1);

        // Commit to a review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        review.decision = IThriveReview.Decision.REJECTED;
        vm.prank(address(0x2));
        thriveReview.createReview(review, 2);

        // Commit to a review
        vm.prank(address(0x3));
        thriveReview.commitToReview(0);

        // Create a review
        review.decision = IThriveReview.Decision.REJECTED;
        vm.prank(address(0x3));
        thriveReview.createReview(review, 3);



        // Check that the submission is finalized
        (, , , , , , IThriveReview.SubmissionStatus submissionStatus) = thriveReview.submissions(0);
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.FINALIZED), "Submission status is not set correctly");

        // Assert balance before claiming
        uint256 balanceBeforeClaimingReward = address(this).balance;

        // Claim reviewer reward
        thriveReview.claimReviewerReward(0);

        // Assert balance after claiming
        uint256 balanceAfterClaimingReward = address(this).balance;

        assertEq(balanceAfterClaimingReward, balanceBeforeClaimingReward, "Reviewer reward should not be claimed for incorrect judgement");
    }


    function test29_fail_ToClaimReviewerRewardTwice() public {
                
        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.createReview(review, 0);


        vm.prank(address(0x1));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x1));
        // Create a review
        thriveReview.createReview(review, 1);


        vm.prank(address(0x2));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x2));
        // Create a review
        thriveReview.createReview(review, 2);

        // Check that the submission is finalized
        (, , , , , , IThriveReview.SubmissionStatus submissionStatus) = thriveReview.submissions(0);
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.FINALIZED), "Submission status is not set correctly");

        // Assert balance before claiming
        uint256 balanceBeforeClaimingReward = address(this).balance;

        // Claim reviewer reward
        thriveReview.claimReviewerReward(0);

        // Assert balance after claiming
        uint256 balanceAfterClaimingReward = address(this).balance;

        assertEq(balanceAfterClaimingReward, balanceBeforeClaimingReward + reviewConfiguration.reviewerReward, "Reviewer reward is not claimed correctly");

        // Get the review
        (, , , , , , IThriveReview.ReviewStatus status) = thriveReview.reviews(0);

        // Assert review is deleted
        assertEq(uint256(status), uint256(IThriveReview.ReviewStatus.DONE), "Review status is not set correctly");

        // This should fail
        vm.expectRevert("User has already claimed the reward");
        thriveReview.claimReviewerReward(0);

    }


    function test30_fail_ToClaimReviewerRewardForOtherUser() public {
        
        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.createReview(review, 0);


        vm.prank(address(0x1));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x1));
        // Create a review
        thriveReview.createReview(review, 1);


        vm.prank(address(0x2));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x2));
        // Create a review
        thriveReview.createReview(review, 2);

        // Check that the submission is finalized
        (, , , , , , IThriveReview.SubmissionStatus submissionStatus) = thriveReview.submissions(0);
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.FINALIZED), "Submission status is not set correctly");

        // Claim reviewer reward should fail for other user
        vm.expectRevert("User has not submitted this review");
        thriveReview.claimReviewerReward(1);

    }


    function test31_fail_ToClaimReviewerRewardForNonFinalizedSubmissions() public {
        
        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.createReview(review, 0);

        // Claim reviewer reward should fail for non-finalized submission
        vm.expectRevert("Submission is not in 'FINALIZED' status");
        thriveReview.claimReviewerReward(0);
    }
    */

   function testxyz_success_CorrectReviewersArePaidOutOnSubmissionFinalization() public {
        
        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        thriveReview.commitToReview(0);

        // Create a review
        thriveReview.createReview(review, 0);


        vm.prank(address(0x1));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x1));
        // Create a review
        thriveReview.createReview(review, 1);


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
        thriveReview.createReview(review, 2);


        // Address 3 makes the right decision
        review.decision = IThriveReview.Decision.ACCEPTED;
        vm.prank(address(0x3));
        // Commit to a review
        thriveReview.commitToReview(0);

        vm.prank(address(0x3));
        // Create a review
        thriveReview.createReview(review, 3);

        // Check that the submission is finalized
        (, , , , , , IThriveReview.SubmissionStatus submissionStatus) = thriveReview.submissions(0);
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.FINALIZED), "Submission status is not set correctly");

        // Assert balance after rewards distribution and submission finalization
        uint256 balanceAfterClaimingReward = address(this).balance;
        uint256 balanceAddress1AfterClaimingReward = address(0x1).balance;
        uint256 balanceAddress2AfterClaimingReward = address(0x2).balance;
        uint256 balanceAddress3AfterClaimingReward = address(0x3).balance;


        assertEq(balanceAfterClaimingReward, balanceBeforeClaimingReward + reviewConfiguration.reviewerReward, "Reviewer reward is not claimed correctly");
        assertEq(balanceAddress1AfterClaimingReward, balanceAddress1BeforeClaimingReward + reviewConfiguration.reviewerReward, "Reviewer reward is not claimed correctly");
        assertEq(balanceAddress2AfterClaimingReward, balanceAddress2BeforeClaimingReward, "Reviewer reward is not claimed correctly");
        assertEq(balanceAddress3AfterClaimingReward, balanceAddress3BeforeClaimingReward + reviewConfiguration.reviewerReward, "Reviewer reward is not claimed correctly");

   }


    function test32_success_CreateReviewContractWithoutAWorkUnit() public {

        // Deploy ThriveReview with no work unit
        address thriveReviewAddressWoWorkUnit = thriveReviewFactory.createReviewContract{value: 10 ether}(
            reviewConfiguration
        );

        ThriveReview thriveReviewWithoutWorkUnit = ThriveReview(payable(thriveReviewAddressWoWorkUnit));

        // Assert storage variables are initialized properly
        assertEq(
            address(thriveReviewWithoutWorkUnit.workerUnitAddress()),
            address(0),
            "WorkUnit address is not set correctly"
        );
    }

    function test33_success_ReviewContractShouldNotRevertWhenFinalizingSubmissionWithoutWorkUnit() public {
        
        // Deploy ThriveReview with no work unit
        address thriveReviewAddressWoWorkUnit = thriveReviewFactory.createReviewContract{value: 10 ether}(
            reviewConfiguration
        );

        ThriveReview thriveReviewWithoutWorkUnit = ThriveReview(payable(thriveReviewAddressWoWorkUnit));

        // Create a submission
        thriveReviewWithoutWorkUnit.createSubmission(submission);

        // Commit to review
        thriveReviewWithoutWorkUnit.commitToReview(0);

        // Create a review
        thriveReviewWithoutWorkUnit.createReview(review, 0);

        // Commit to review
        vm.prank(address(0x1));
        thriveReviewWithoutWorkUnit.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReviewWithoutWorkUnit.createReview(review, 1);

        // Commit to review
        vm.prank(address(0x2));
        thriveReviewWithoutWorkUnit.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        thriveReviewWithoutWorkUnit.createReview(review, 2);


        // Check that the submission is finalized
        (, , , , , , IThriveReview.SubmissionStatus submissionStatus) = thriveReviewWithoutWorkUnit.submissions(0);
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.FINALIZED), "Submission status is not set correctly");
    }


    function testxx_success_RetrieveFundsAsOwner() public {
        uint256 balanceBefore = address(this).balance;

        thriveReview.retrieveFunds();

        uint256 balanceAfter = address(this).balance;

        assertEq(balanceAfter, balanceBefore + 10 ether, "Owner should be able to retrieve funds");
    }

    function testxx_fail_ToRetrieveFundsAsNonOwner() public {

        vm.prank(randomUser);
        vm.expectRevert();
        thriveReview.retrieveFunds();
    }

    function testxx_success_ReachDecisionOnSubmissionAsBadgeAfterMaxReviews() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.createReview(review, 0);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        thriveReview.createReview(review, 1);



        // Make following reviews REJECTED
        review.decision = IThriveReview.Decision.REJECTED;

        // Commit to review
        vm.prank(address(0x3));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x3));
        thriveReview.createReview(review, 2);

        // Commit to review
        vm.prank(address(0x4));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x4));
        thriveReview.createReview(review, 3);


        // Check that the submission is still pending because there is no consensus on decision
        (, , , , , IThriveReview.Decision decision, IThriveReview.SubmissionStatus submissionStatus) = thriveReview.submissions(0);
        assertEq(uint256(decision), uint256(IThriveReview.Decision.NONE), "Submission status is not set correctly");
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.PENDING), "Submission status is not set correctly");


        // Finalize this submission as a judge badge
        thriveReview.reachDecisionOnSubmissionAsBadge(0, IThriveReview.Decision.ACCEPTED);


        // Check that the submission is still pending because there is no consensus on decision
        (, , , , , decision, submissionStatus) = thriveReview.submissions(0);
        assertEq(uint256(decision), uint256(IThriveReview.Decision.ACCEPTED), "Submission status is not set correctly");
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.FINALIZED), "Submission status is not set correctly");

    }


    function testxy_success_CorrectReviewersArePaidOutOnBadgeSubmissionFinalization() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.createReview(review, 0);


        // Change the users decision to REJECTED
        review.decision = IThriveReview.Decision.REJECTED;
        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        thriveReview.createReview(review, 1);

        // Users balances before distributing reviewer rewards
        uint256 balanceAddress1BeforeClaimingReward = address(0x1).balance;
        uint256 balanceAddress2BeforeClaimingReward = address(0x2).balance;

        vm.warp(reviewConfiguration.reviewDeadline + 1);
        thriveReview.reachDecisionOnSubmissionAsBadge(0, IThriveReview.Decision.REJECTED);

        // Users balances after distributing reviewer rewards
        uint256 balanceAddress1AfterClaimingReward = address(0x1).balance;
        uint256 balanceAddress2AfterClaimingReward = address(0x2).balance;

        // Make sure that the reviewer rewards are distributed correctly
        assertEq(balanceAddress1AfterClaimingReward, balanceAddress1BeforeClaimingReward, "Reviewer reward is not claimed correctly");
        assertEq(balanceAddress2AfterClaimingReward, balanceAddress2BeforeClaimingReward + reviewConfiguration.reviewerReward, "Reviewer reward is not claimed correctly");

    }


    function testxx_success_ReachDecisionOnSubmissionAsBadgeAfterReviewDeadline() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.createReview(review, 0);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        thriveReview.createReview(review, 1);

        // Go to right after the review deadline
        vm.warp(reviewConfiguration.reviewDeadline + 1);

        // Finalize this submission as a judge badge
        thriveReview.reachDecisionOnSubmissionAsBadge(0, IThriveReview.Decision.ACCEPTED);

        // Check that the submission is still pending because there is no consensus on decision
        (, , , , , IThriveReview.Decision decision, IThriveReview.SubmissionStatus submissionStatus) = thriveReview.submissions(0);
        assertEq(uint256(decision), uint256(IThriveReview.Decision.ACCEPTED), "Submission status is not set correctly");
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.FINALIZED), "Submission status is not set correctly");
    }

    function testxx_fail_ToReachDecisionOnSubmissionAsBadgeBeforeDeadlineWithoutMaxReviews() public {
        
        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.createReview(review, 0);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        thriveReview.createReview(review, 1);

        // Fail to finalize
        vm.expectRevert("Submission has not reached requirements for a final decision as badge");
        thriveReview.reachDecisionOnSubmissionAsBadge(0, IThriveReview.Decision.ACCEPTED);
    }

    function testxx_fail_ToReachDecisionOnSubmissionAsBadgeWithNoProperDecision() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.createReview(review, 0);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        thriveReview.createReview(review, 1);

        // Go to right after the review deadline
        vm.warp(reviewConfiguration.reviewDeadline + 1);

        // Fail to finalize
        vm.expectRevert("Decision must be either 'ACCEPTED' or 'REJECTED'");
        thriveReview.reachDecisionOnSubmissionAsBadge(0, IThriveReview.Decision.NONE);

    }

    function testxx_fail_ToReachDecisionAsBadgeOnNonPendingSubmission() public {

        // Create a submission
        thriveReview.createSubmission(submission);

        // Commit to review
        vm.prank(address(0x1));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x1));
        thriveReview.createReview(review, 0);

        // Commit to review
        vm.prank(address(0x2));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x2));
        thriveReview.createReview(review, 1);

        // Commit to review
        vm.prank(address(0x3));
        thriveReview.commitToReview(0);

        // Create a review
        vm.prank(address(0x3));
        thriveReview.createReview(review, 2);

        // Check that the submission is still finalized
        (, , , , , IThriveReview.Decision decision, IThriveReview.SubmissionStatus submissionStatus) = thriveReview.submissions(0);
        assertEq(uint256(decision), uint256(IThriveReview.Decision.ACCEPTED), "Submission status is not set correctly");
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.FINALIZED), "Submission status is not set correctly");

        vm.expectRevert("Submission is not in 'PENDING' status");
        thriveReview.reachDecisionOnSubmissionAsBadge(0, IThriveReview.Decision.ACCEPTED);
    }


    receive() external payable {}

}
