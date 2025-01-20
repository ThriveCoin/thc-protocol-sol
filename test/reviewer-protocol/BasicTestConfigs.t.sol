// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// This file contains basic struct/object configurations for the unit tests in the reviewer protocol.

import {Test} from "forge-std/Test.sol";

import "../../src/interface/IThriveWorkerUnitFactory.sol";
import "../../src/reviewer-protocol/interface/IThriveReview.sol";


abstract contract BasicTestConfigs is Test {
    IThriveWorkerUnitFactory.WorkUnitArgs workUnitArgs;
    IThriveReview.ReviewConfiguration reviewConfiguration;
    IThriveReview.Submission submission;
    IThriveReview.Review review;

    address[] public validators;

    uint256 public constant REVIEW_CONTRACT_ALLOCATION = 8_000;

    uint256 SUBMITTER_LOCKED_FUNDS;

    // When you write it, you can deploy the real contract
    address public badgeQueryContractAddress =
        address(uint160(uint256(keccak256(abi.encodePacked("badgeQuery")))));

    
    bytes32[] submitterBadges = new bytes32[](1);


    constructor() {
        validators.push(address(0x1));
        validators.push(address(0x2));

        submitterBadges[0] = keccak256(abi.encodePacked("submitterBadge"));

        // Some data is intentionally wrongly filled because only some fields are written on-chain
        // and we want to prevent users from manipulating this data
        workUnitArgs = IThriveWorkerUnitFactory.WorkUnitArgs({
            moderator: address(this),
            rewardToken: address(0),
            rewardAmount: 10,
            maxRewards: 100 ether,
            validationRewardAmount: 0,
            deadline: 10 days,
            maxCompletionsPerUser: 2,
            validators: validators,
            assignedContributor: address(0),
            badgeQuery: badgeQueryContractAddress
        });

        reviewConfiguration = IThriveReview.ReviewConfiguration({
            workUnit: address(0),
            reviewerRewardsTotalAllocation: 8_000,
            reviewerReward: 400,
            agreementThreshold: 7_000, // 70%
            maximumSubmissionsPerUser: 2,
            minimumReviews: 3,
            maximumSubmissions: 5,
            maximumReviewsPerSubmission: 4,
            submissionDeadline: uint32(block.timestamp) + 10 days,
            reviewCommitmentPeriod: 1 days,
            reviewDeadlinePeriod: 7 days,
            submitterBadges: submitterBadges,
            reviewerBadges: new bytes32[](0),
            judgeBadges: new bytes32[](0),
            disputeResolverBadges: new bytes32[](0),
            reviewMetadata: "reviewMetadata",
            submissionMetadata: "submissionMetadata"
        });

        submission = IThriveReview.Submission({
            id: 0,
            contributor: address(this),
            submissionMetadata: "",
            reviewCount: 123,
            acceptedReviewsCount: 10,
            rejectedReviewsCount: 213,
            reviewDeadline: 1234,
            disputeDeadline: 0,
            decision: IThriveReview.Decision.ACCEPTED,
            status: IThriveReview.SubmissionStatus.PENDING
        });

        review = IThriveReview.Review({
            id: 0,
            submissionId: 1,
            // This is not written on-chain
            reviewer: address(this),
            reviewMetadata: "reviewMetadata",
            deadline: 1 days,
            // This is not written on-chain
            decision: IThriveReview.Decision.ACCEPTED,
            // This is not written on-chain
            status: IThriveReview.ReviewStatus.COMMITTED
        });
    }
}


