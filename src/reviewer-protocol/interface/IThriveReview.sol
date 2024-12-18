// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IThriveReviewFactory.sol";

/**
 * @title IThriveReview
 * @dev Interface for ThriveReview contract.
 */
interface IThriveReview {

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

    // Submissions store details of the request for review of a completed work unit.
    struct Submission {
        // Reference to the work unit being submitted for review
        address workUnit;
        // Reference to the review configuration used to evaluate the submission
        IThriveReviewFactory.ReviewConfiguration reviewConfiguration;
        // The EVM address of the contributor submitting the work unit for review
        address contributor;
        // JSON object that contains the information shown to reviewers during the review process
        string submissionMetadata;
        // The current status of the submission
        ReviewStatus status;
    }

    // Status of a review
    enum ReviewStatus {
        PENDING,
        IN_PROGRESS,
        COMPLETED
    }

    // Create a submission for review
    function createSubmission(Submission memory) external;

    // Remove pending reviews after a certain deadline
    function removePendingReviews(uint256) external;

    // Submit a review
    function submitReview(Review memory) external;

    // User commits to do a review of a certain submission
    function commitToReview(uint256) external;

    // Any user can trigger the deletion of a pending review if the review window has expired without the review being completed.
    function deletePendingReview(uint256) external;

}
