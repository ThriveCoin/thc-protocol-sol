// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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