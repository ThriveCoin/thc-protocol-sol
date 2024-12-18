// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IThriveReview
 * @dev Interface for ThriveReview contract.
 */
interface IThriveReview {

/*
    // Review content submiteed by a reviewer
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

    // Review status
    enum ReviewStatus {
        PENDING,
        IN_PROGRESS,
        COMPLETED
    }

    // Create a submission for review
    function createSubmission() external;

    // Remove pending reviews after a certain deadline
    function removePendingReviews() external;

    // Submit a review
    function submitReview() external;

    // User commits to do a review of a certain submission
    function commitToReview() external;

    // Any user can trigger the deletion of a pending review if the review window has expired without the review being completed.
    function deletePendingReview() external;

*/
}
