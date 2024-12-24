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
        SubmissionStatus status;
    }

    
    // Reviews store details of each review conducted on a submission.
    struct Review {
        // Reference to a submission
        uint256 submissionId;
        // The address of the reviewer
        address reviewer;
        // The ThriveReview metadata
        string reviewMetadata;
        // Deadline for a committed review to be completed
        uint256 deadline;
        // The reviewers' decision on a particular submission
        ReviewDecision decision;
        // The status of the review
        ReviewStatus status;
    }

    // Status of a ThriveReview submission
    enum SubmissionStatus {
        NONE,
        PENDING,
        ACCEPTED,
        REJECTED
    }

    // Status of a review object for a submission
    enum ReviewStatus {
        NONE,
        COMMITED,
        EXPIRED, // When there needs to be room made for other commits
        DONE
    }

    // Review decision on a particular submission
    enum ReviewDecision {
        NONE,
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
}
