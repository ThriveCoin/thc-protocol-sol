// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IThriveReviewFactory.sol";

/**
 * @title IThriveReview
 * @dev Interface for ThriveReview contract.
 */
interface IThriveReview {

    // @dev Add desc on this
    struct Submission {
        // The EVM address of the contributor submitting the work unit for review
        address contributor;
        // JSON object that contains the information shown to reviewers during the review process
        string submissionMetadata;
        // The status of the submission
        ReviewStatus status;
    }

    
    // Reviews store details of each review conducted on a submission.
    struct Review {
        // Reference to a submission
        uint256 submissionId;
        // The address of the reviewer
        address reviewer;
        // The ThriveReview metadata
        string reviewMetadata;
        // The reviewers' decision on a particular submission
        ReviewDecision decision;
    }

    // Status of a ThriveReview
    enum ReviewStatus {
        PENDING,
        ACCEPTED,
        REJECTED
    }

    // Review decision on a particular submission
    enum ReviewDecision {
        ACCEPTED,
        REJECTED
    }

    /**
     * @notice Initializes a newly created ThriveReview contract.
     * @param reviewConfiguration_ Struct describing how reviews will be handled.
     * @param workUnitContractAddress_ Address of the ThriveWorkUnit contract.
     * @param thriveReviewFactoryAddress_ Address of the ThriveReviewFactory contract.
     * @param badgeQueryContractAddress_ Address of the BadgeQuery contract.
     * @param owner_ Address of the owner of the contract.
     */
    function initialize(
        IThriveReviewFactory.ReviewConfiguration memory reviewConfiguration_,
        address workUnitContractAddress_,
        address thriveReviewFactoryAddress_,
        address badgeQueryContractAddress_,
        address owner_
    ) external;

    /**
     * @notice Creates a new submission.
     * @param submission_ struct submitted for the work unit
     */
    function createSubmission(Submission calldata submission_) external;

    /**
     * @notice Edits an existing submission.
     * @param editedSubmission_ struct submitted for the work unit.
     * @param submissionId_ struct submitted for the work unit.
     */
    function updateSubmission(Submission calldata editedSubmission_, uint256 submissionId_) external;


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

    /**
     * @notice Checks if this ThriveReview contract has a ThriveWorkUnit contract connected to it.
     * @return True if the contract has a work unit contract, false otherwise.
     */
    function hasWorkUnitContract() external view returns (bool);
}
