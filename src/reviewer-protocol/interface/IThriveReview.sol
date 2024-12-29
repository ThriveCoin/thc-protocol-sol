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
        // The number of reviews that have been conducted on the submission
        uint256 reviewCount;
        // The number of reviews that have been accepted
        uint256 acceptedReviewsCount;
        // The number of reviews that have been rejected
        uint256 rejectedReviewsCount;
        // Review decision on this submission - saved after conditions for reaching a verdict are met
        Decision decision;
        // The status of the submission
        SubmissionStatus status;
    }

    // Reviews store details of each review conducted on a submission.
    struct Review {
        // Review id in contract
        uint256 id;
        // Reference to a submission
        uint256 submissionId;
        // The address of the reviewer
        address reviewer;
        // The ThriveReview metadata
        string reviewMetadata;
        // Deadline for a committed review to be completed
        uint256 deadline;
        // The reviewers' decision on a particular submission
        Decision decision;
        // The status of the review
        ReviewStatus status;
    }

    // Status of a ThriveReview submission
    enum SubmissionStatus {
        NONE,
        PENDING,
        FINALIZED
    }

    // Status of a review object for a submission
    enum ReviewStatus {
        NONE,
        COMMITED,
        DONE
    }

    // Review decision on a particular submission
    enum Decision {
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
     * @param owner_ Address of the creator of the work unit and review contract.
     */
    function initialize(
        IThriveReviewFactory.ReviewConfiguration memory reviewConfiguration_,
        address workUnitContractAddress_,
        address thriveReviewFactoryAddress_,
        address badgeQueryContractAddress_,
        address owner_
    ) external;
}
