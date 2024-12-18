// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct ReviewConfiguration {
    // Represents the address of the WorkerUnit contract.
    address workerUnit; // @dev change to IWorkerUnit
    // Amount of THRIVE paid to reviewers for completing an accurate review.
    uint256 reviewerReward;
    // The percentage of agreement required to make a final decision.
    uint256 agreementThreshold;
    // The minimum number of reviews needed to make a decision.
    uint256 minimumReviews;
    // The maximum number of reviews that can be conducted for a submission.
    uint256 maximumReviews;
    // The time allowed for a reviewer to complete their review.
    uint256 reviewWindow;
    // An array of badges required for an EVM address to participate in the review.
    // Pending: We'll see how to handle this in code
    // JSON object containing descriptive information for the review, such as review summary, reviewer instructions, and estimated time to complete the review.
    string reviewMetadata;
    // Reference to the submission or its metadata.
    // Pending: We'll see how to handle this in code
}

struct Review {
    // Reference to a submission
    uint256 submissionId; // @dev this is probably not a correct way to reference a submission
    // The address of the reviewer
    address reviewer;
    // The review metadata
    string reviewMetadata;
    // The reviewers' decision
    bool decision; // accepted or rejected
}

enum ReviewStatus {
    PENDING,
    IN_PROGRESS,
    COMPLETED
}