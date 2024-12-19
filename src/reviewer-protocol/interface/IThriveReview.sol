// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IThriveReviewFactory.sol";

/**
 * @title IThriveReview
 * @dev Interface for ThriveReview contract.
 */
interface IThriveReview {

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

    // Status of a review
    enum ReviewStatus {
        PENDING,
        IN_PROGRESS,
        COMPLETED
    }

    /**
     * @notice Creates a new submission.
     * @param submission_ struct submitted for the work unit
     */
    function createSubmission(Submission memory submission_) external;

    /**
     * @notice Submits a review of a certain submission.
     * @param review_ Review struct submitted
     */
    function createReview(Review memory review_) external;

    /**
     * @notice Removes pending reviews that have passed a certain time deadline.
     * @param reviewIds_ Array of review IDs to remove
     */
    function deletePendingReviews(uint256[] calldata reviewIds_) external;

    /**
     * @notice Deletes a pending review.
     * @param reviewId_ The ID of the review to delete
     */
    function deletePendingReview(uint256 reviewId_) external;

    /**
     * @notice Commits to review a submission.
     * @param submissionId_ The ID of the submission to review
     */
    function commitToReview(uint256 submissionId_) external;
}
