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
        // The amount of THRIVE allocated for reviewers.
        uint256 reviewerRewardsTotalAllocation;
        // The amount of THRIVE paid to reviewers for completing an accurate review.
        uint32 reviewerReward;
        // The percentage of agreement required to make a final decision.
        // Percentage is represented as a number between 0 and 10_000.
        uint32 agreementThreshold;
        // Maximum amount of submissions one user can submit.
        uint32 maximumSubmissionsPerUser;
        // The minimum number of reviews needed to make a decision.
        uint32 minimumReviews;
        // The maximum amount of submissions allowed for a work unit.
        uint32 maximumSubmissions;
        // The maximum number of reviews that can be conducted for a submission.
        uint32 maximumReviewsPerSubmission;
        // The time until contributor is allowed to submit their work unit submission.
        uint32 submissionDeadline;
        // The time allowed for a reviewer to complete their review after commiting to it.
        uint32 reviewCommitmentDeadline;
        // An array of badges required for a user to contribute submissions.
        bytes32[] submitterBadges;
        // An array of badges required for a user to review submissions.
        bytes32[] reviewerBadges;
        // An array of badges required for a user to be able to make a decision on a submission under certain terms.
        bytes32[] judgeBadges;
        // JSON object containing descriptive information for the review, such as review summary, reviewer instructions, and estimated time to complete the review.
        string reviewMetadata;
        // JSON object containing descriptive information for the submission, used by dApps to enhance the user experience during the submission process.
        string submissionMetadata;
    }
}
