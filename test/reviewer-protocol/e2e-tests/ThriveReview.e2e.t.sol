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
    address submitter5 = address(0x5);


    address reviewer1 = address(0x11);
    address reviewer2 = address(0x12);
    address reviewer3 = address(0x13);
    address reviewer4 = address(0x14);


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

        // Create a ThriveWorkUnit and ThriveReview contract
        (thriveReviewAddress, thriveWorkerUnitAddress) = thriveReviewFactory
            .createWorkUnitAndReviewContract{value: REVIEW_CONTRACT_ALLOCATION}(
            workUnitArgs, reviewConfiguration, address(this)
        );

        // Instantiate the ThriveReview contract
        thriveReview = ThriveReview(payable(thriveReviewAddress));

        mockToken.approve(address(thriveWorkerUnitAddress), 1_000 ether);

        // Initialize the ThriveWorkerUnit contract
        IThriveWorkerUnit(thriveWorkerUnitAddress).initialize();


        // Add required badge to ThriveWorkerUnit
        IThriveWorkerUnit(thriveWorkerUnitAddress).addRequiredBadge(keccak256("TestBadge"));

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
        SUBMITTER_LOCKED_FUNDS = reviewConfiguration.reviewerReward * reviewConfiguration.maximumReviewsPerSubmission;

    }

    // Path of maximum submissions, some get accepted, some get rejected
    // Ensure all state storage is valid and payouts are done correctly (on reviewer protocol and on ThriveWorkerUnit)
    // Test is MEANT TO BE COMPLEX TO FOLLOW because it is trying to emulate a real-world scenario
    function test_FullEnd2EndPathOfReviewerProtocol() public {

        /// We will have 5 submissions
        /// 1st submission will be rejected
        /// 2nd submission will be accepted
        /// 3rd submission will be accepted by 75%
        /// 4th submission will be judged by judge badge
        /// 5th submission will be rejected by 75%

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
        review.id=2;
        review.decision = IThriveReview.Decision.REJECTED;
        thriveReview.createReview(review);

        vm.prank(reviewer2);
        review.id=3;
        review.decision = IThriveReview.Decision.ACCEPTED;
        thriveReview.createReview(review);


        // Fetch first submission
        (uint256 id, uint64 reviewCount, uint64 acceptedReviewsCount, uint64 rejectedReviewsCount, , , , IThriveReview.Decision decision, IThriveReview.SubmissionStatus submissionStatus) = thriveReview.idToSubmission(0);

        // Assert submission storage state is as expected
        assertEq(reviewCount, 1, "Review count should be 1 for submission 0");
        assertEq(acceptedReviewsCount, 0, "Accepted reviews count should be 0 for submission 0");
        assertEq(rejectedReviewsCount, 1, "Rejected reviews count should be 1 for submission 0");
        assertEq(uint256(decision), uint256(IThriveReview.Decision.NONE), "Decision should be NONE for submission 0");
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.PENDING), "Submission status should be PENDING for submission 0");


        // Fetch second submission
        (id, reviewCount, acceptedReviewsCount, rejectedReviewsCount, , , , decision, submissionStatus) = thriveReview.idToSubmission(1);

        // Assert submission storage state is as expected
        assertEq(reviewCount, 1, "Review count should be 1 for submission 1");
        assertEq(acceptedReviewsCount, 1, "Accepted reviews count should be 1 for submission 1");
        assertEq(rejectedReviewsCount, 0, "Rejected reviews count should be 0 for submission 1");
        assertEq(uint256(decision), uint256(IThriveReview.Decision.NONE), "Decision should be NONE for submission 1");
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.PENDING), "Submission status should be PENDING for submission 1");



        // Reviewer 1 & 2 & 3 commit to review submisison 3
        vm.prank(reviewer1);
        thriveReview.commitToReview(2); // id: 4

        vm.prank(reviewer2);
        thriveReview.commitToReview(2); // id: 5

        vm.prank(reviewer3);
        thriveReview.commitToReview(2); // id: 6


        // Reviewer 3 creates review for submission 3
        vm.prank(reviewer3);
        review.id=6;
        review.decision = IThriveReview.Decision.ACCEPTED;
        thriveReview.createReview(review);



        // Reviewer 1 creates review for submission 1 and 2
        vm.prank(reviewer1);
        review.id=0;
        review.decision = IThriveReview.Decision.REJECTED;
        thriveReview.createReview(review);

        vm.prank(reviewer1);
        review.id=1;
        review.decision = IThriveReview.Decision.ACCEPTED;
        thriveReview.createReview(review);


        // Reviewer 3 commits to review submission 1
        vm.prank(reviewer3);
        thriveReview.commitToReview(0); // id: 7

        // Reviewer 3 creates review for submission 1
        vm.prank(reviewer3);
        review.id=7;
        review.decision = IThriveReview.Decision.REJECTED;
        thriveReview.createReview(review);


        // Fetch third submission
        (id, reviewCount, acceptedReviewsCount, rejectedReviewsCount, , , , decision, submissionStatus) = thriveReview.idToSubmission(0);

        // Assert submission storage state is as expected
        assertEq(reviewCount, 3, "Review count should be 3 for submission 0");
        assertEq(acceptedReviewsCount, 0, "Accepted reviews count should be 0 for submission 0");
        assertEq(rejectedReviewsCount, 3, "Rejected reviews count should be 3 for submission 0");
        assertEq(uint256(decision), uint256(IThriveReview.Decision.REJECTED), "Decision should be REJECTED for submission 0");
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.FINALIZED), "Submission status should be FINALIZED for submission 0");



        /////// We will write payout tests after implementing DISPUTE functionality
        ///////////////////////
        ////////////////////////////////////////



        // Create fourth submission for user 4 - this one will be judged by judge badge
        vm.prank(submitter4);
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission); // id: 3



        // Reviewer 3 commits to review submission 2 
        vm.prank(reviewer3);
        thriveReview.commitToReview(1); // id: 8

        // Reviewer 3 creates review for submission 2
        vm.prank(reviewer3);
        review.id=8;
        review.decision = IThriveReview.Decision.ACCEPTED;
        thriveReview.createReview(review);


        (id, reviewCount, acceptedReviewsCount, rejectedReviewsCount, , , , decision, submissionStatus) = thriveReview.idToSubmission(1);

        // Assert submission storage state is as expected
        assertEq(reviewCount, 3, "Review count should be 3 for submission 1");
        assertEq(acceptedReviewsCount, 3, "Accepted reviews count should be 3 for submission 1");
        assertEq(rejectedReviewsCount, 0, "Rejected reviews count should be 0 for submission 1");
        assertEq(uint256(decision), uint256(IThriveReview.Decision.ACCEPTED), "Decision should be REJECTED for submission 1");
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.FINALIZED), "Submission status should be FINALIZED for submission 1");



        // Reviewer 4 commits to review submission 3
        vm.prank(reviewer4);
        thriveReview.commitToReview(2); // id: 9

        // Reviewer 4 creates review for submission 3
        vm.prank(reviewer4);
        review.id=9;
        review.decision = IThriveReview.Decision.REJECTED;
        thriveReview.createReview(review);


        // Reviewer 1 creates review for submission 3
        vm.prank(reviewer1);
        review.id=4;
        review.decision = IThriveReview.Decision.ACCEPTED;
        thriveReview.createReview(review);



        // Create fifth submission for user 5 - this one will be rejected by 75%
        vm.prank(submitter5);
        thriveReview.createSubmission{value: SUBMITTER_LOCKED_FUNDS}(submission); // id: 4



        // Reviewer 4 commits to review submission 4
        vm.prank(reviewer4);
        thriveReview.commitToReview(3); // id: 10


        // Reviewer 3 commits to review submission 4
        vm.prank(reviewer3);
        thriveReview.commitToReview(3); // id: 11

        // Reviewer 3 creates review for submission 4
        vm.prank(reviewer3);
        review.id=11;
        review.decision = IThriveReview.Decision.REJECTED;
        thriveReview.createReview(review);

        // Reviewer 2 creates review for submission 3
        vm.prank(reviewer2);
        review.id=5;
        review.decision = IThriveReview.Decision.ACCEPTED;
        thriveReview.createReview(review);
        

        // Fetch submission 3
        (id, reviewCount, acceptedReviewsCount, rejectedReviewsCount, , , , decision, submissionStatus) = thriveReview.idToSubmission(2);

        // Assert submission storage state is as expected
        assertEq(reviewCount, 4, "Review count should be 3 for submission 2");
        assertEq(acceptedReviewsCount, 3, "Accepted reviews count should be 2 for submission 2");
        assertEq(rejectedReviewsCount, 1, "Rejected reviews count should be 1 for submission 2");
        assertEq(uint256(decision), uint256(IThriveReview.Decision.ACCEPTED), "Decision should be ACCEPTED for submission 2");
        assertEq(uint256(submissionStatus), uint256(IThriveReview.SubmissionStatus.FINALIZED), "Submission status should be FINALIZED for submission 2");


        ////// STILL HAVE TO FINISH SUBMISSION 4 AND 5
    }

}