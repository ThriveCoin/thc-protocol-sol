// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import "../../../src/interface/IThriveWorkUnitFactory.sol";
import "../../../src/reviewer-protocol/interface/IThriveReviewFactory.sol";
import "../../../src/reviewer-protocol/interface/IThriveReview.sol";

abstract contract BasicTestConfigs is Test {
    IThriveWorkUnitFactory.WorkUnitArgs workUnitArgs;
    IThriveReview.ReviewConfiguration reviewConfiguration;
    IThriveReview.Submission submission;
    IThriveReview.Review review;

    address[] public validators;

    // When you write it, you can deploy the real contract
    address public badgeQueryContractAddress =
        address(uint160(uint256(keccak256(abi.encodePacked("badgeQuery")))));

    constructor() {
        validators.push(address(0x1));
        validators.push(address(0x2));

        workUnitArgs = IThriveWorkUnitFactory.WorkUnitArgs({
            moderator: address(this),
            rewardToken: address(0),
            rewardAmount: 10,
            maxRewards: 100 ether,
            validationRewardAmount: 1,
            deadline: block.timestamp + 1 days,
            maxCompletionsPerUser: 2,
            validators: validators,
            assignedContributor: address(0),
            badgeQuery: badgeQueryContractAddress
        });

        reviewConfiguration = IThriveReview.ReviewConfiguration({
            workUnit: address(0),
            reviewerRewardsTotalAllocation: 10 ether,
            reviewerReward: 400_000_000_000_000_000, // 0.4 THRIVE
            agreementThreshold: 9_000, // 90%
            maximumSubmissionsPerUser: 2,
            minimumReviews: 3,
            maximumSubmissions: 5,
            maximumReviewsPerSubmission: 3,
            submissionDeadline: uint32(block.timestamp) + 10 days,
            reviewCommitmentDeadline: 1 days,
            submitterBadges: new bytes32[](0),
            reviewerBadges: new bytes32[](0),
            judgeBadges: new bytes32[](0),
            reviewMetadata: "reviewMetadata",
            submissionMetadata: "submissionMetadata"
        });

        submission = IThriveReview.Submission({
            contributor: address(this),
            submissionMetadata: "",
            reviewCount: 123,
            acceptedReviewsCount: 10,
            rejectedReviewsCount: 213,
            decision: IThriveReview.Decision.ACCEPTED,
            status: IThriveReview.SubmissionStatus.PENDING
        });

        // Some data is intentionally wrongly filled because only some fields are written on-chain
        // and we want to prevent users from manipulating this data
        review = IThriveReview.Review({
            id: 1,
            submissionId: 1,
            reviewer: address(this),
            reviewMetadata: "reviewMetadata",
            deadline: 1 days,
            decision: IThriveReview.Decision.ACCEPTED,
            status: IThriveReview.ReviewStatus.COMMITED
        });
    }
}
