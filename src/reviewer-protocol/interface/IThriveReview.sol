// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


/**
 * @title IThriveReview
 * @dev Interface for ThriveReview contract.
 */
interface IThriveReview {

    // @dev Add desc on this
    struct ReviewConfiguration {

        // Reference to the ThriveWorkUnit on the Thrive Protocol which the configuration is being created for.
        address workUnit; // Can also use IWorkUnit interface

        // The amount of THRIVE allocated for reviewers.
        uint256 reviewerRewardsTotalAllocation;

        // The amount of THRIVE paid to reviewers for completing an accurate review.
        uint256 reviewerReward;

        // The percentage of agreement required to make a final decision.
        // Percentage is represented as a number between 0 and 10_000.
        uint32 agreementThreshold;

        // Maximum amount of submissions one user can submit.
        uint32 maximumSubmissionsPerUser;

        // The minimum number of reviews needed to make a decision.
        uint32 minimumReviews;

        // The maximum amount of submissions allowed for a work unit.
        // This variable should most likely be derived from maxSubmissionsPerUser * users participating in the work unit.
        uint32 maximumSubmissions;

        // The maximum number of reviews that can be conducted for a submission.
        uint32 maximumReviewsPerSubmission;
        // The time until contributor is allowed to submit their work unit submission.

        uint32 submissionDeadline;

        // The time allowed for a reviewer to complete their review after commiting to it.
        uint32 reviewCommitmentDeadline;

        // Timestamp until when reviewing is allowed.
        uint32 reviewDeadline;

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
        COMMITTED,
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
     * @param thriveReviewFactoryAddress_ Address of the ThriveReviewFactory contract.
     * @param badgeQueryContractAddress_ Address of the BadgeQuery contract.
     * @param owner_ Address of the creator of the work unit and review contract.
     */
    function initialize(
        ReviewConfiguration memory reviewConfiguration_,
        address thriveReviewFactoryAddress_,
        address badgeQueryContractAddress_,
        address owner_
    ) external;
}
