// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IThriveReviewFactory
 * @dev Interface for ThriveReviewFactory contract.
 */
interface IThriveReviewFactory {

    // @dev Add desc on this
    struct ReviewConfiguration {

        // Reference to the ThriveWorkUnit on the Thrive Protocol for which the configuration is being created.
        address workUnit; // Can also use IWorkUnit interface
        // The amount of THRIVE paid to reviewers for completing an accurate review.
        uint256 totalReviewerReward;
        // The percentage of agreement required to make a final decision.
        uint64 agreementThreshold;
        // The minimum number of reviews needed to make a decision.
        uint64 minimumReviews;
        // The maximum number of reviews that can be conducted for a submission.
        uint64 maximumReviews;
        // The time allowed for a reviewer to complete their review.
        uint64 reviewWindow;
        // An array of badges required for an EVM address to participate in the review.
        bytes32[] reviewerBadges;
        // JSON object containing descriptive information for the review, such as review summary, reviewer instructions, and estimated time to complete the review.
        string reviewMetadata;
        // JSON object containing descriptive information for the submission, used by dApps to enhance the user experience during the submission process.
        string submissionMetadata;
    }
}