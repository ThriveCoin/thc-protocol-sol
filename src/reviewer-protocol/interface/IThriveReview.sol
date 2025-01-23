// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IThriveReview
 * @dev Interface for ThriveReview contract.
 */
interface IThriveReview {
    // Configuration for a ThriveReview contract.
    struct ReviewConfiguration {
        // Reference to the ThriveWorkUnit on the Thrive Protocol which the ThriveReview is being created for to act as validator.
        address workUnit; // Can also use IWorkUnit interface
        // The amount of THRIVE allocated for reviewers.
        uint256 reviewerRewardsTotalAllocation;
        // The amount of THRIVE paid to reviewers for completing an accurate review.
        uint256 reviewerReward;
        // The percentage of agreement required to make a final decision.
        uint32 agreementThreshold; // Percentage is represented as a number between 0 and 10_000. (e.g. 70% = 7_000)
        // Maximum amount of submissions ONE (1) user can submit.
        uint32 maximumSubmissionsPerUser;
        // The minimum number of reviews a submission must have in order to reach a decision.
        uint32 minimumReviews;
        // The maximum amount of submissions allowed to be submitted.
        uint32 maximumSubmissions; // This variable should most likely be derived from maxSubmissionsPerUser * users participating in the work unit.
        // The maximum number of reviews that can be conducted for a submission.
        uint32 maximumReviewsPerSubmission;
        // The time/date until contributor is allowed to submit their work unit submission. (specified as a date, not period e.g. 25th of January 2025)
        uint32 submissionDeadline;
        // The time period allowed for a reviewer to complete their review after commiting to it. (e.g. 10 days)
        uint32 reviewCommitmentPeriod;
        // Fixed period for reviews after a submission is created. (e.g. 10 days)
        uint32 reviewDeadlinePeriod;
        // An array of badges required for a user to contribute submissions.
        bytes32[] submitterBadges;
        // An array of badges required for a user to review submissions.
        bytes32[] reviewerBadges;
        // An array of badges required for a user to be able to make a decision on a submission.
        bytes32[] judgeBadges;
        // An array of badges required for an address to resolve disputes.
        bytes32[] disputeResolverBadges;
        // JSON object containing descriptive information for the review, such as review summary, reviewer instructions, and estimated time to complete the review.
        string reviewMetadata;
        // JSON object containing descriptive information for the submission, used by dApps to enhance the user experience during the submission process.
        string submissionMetadata;
    }

    // Submission object that stores all details of a submission.
    struct Submission {
        // Submission id in contract state.
        uint256 id;
        // The number of reviews that have been conducted on the submission.
        uint32 reviewCount;
        // The number of reviews that have reviewed the submission ACCEPTED.
        uint32 acceptedReviewsCount;
        // The number of reviews that have reviewed the submission REJECTED.
        uint32 rejectedReviewsCount;
        // The timestamp until the submission can be reviewed. (Set in contract)
        uint64 reviewDeadline;
        // The timestamp until the submission decision can be disputed. (Set in contract)
        uint64 disputeDeadline;
        // The EVM address of the contributor submitting the submission for review
        address contributor;
        // JSON object that contains the information shown to reviewers during the review process
        string submissionMetadata;
        // Metadata containing judge decision on the submission - This is filled when a judge HAS TO finalize a submission.
        string judgeDecisionMetadata;
        // Review decision on this submission - saved after conditions for reaching a verdict are met.
        Decision decision;
        // The status of the submission
        SubmissionStatus status;
    }

    // Reviews store details of each review conducted on a submission.
    struct Review {
        // Review id in contract
        uint256 id;
        // Reference to the submission
        uint256 submissionId;
        // The address of the reviewer
        address reviewer;
        // The ThriveReview metadata
        string reviewMetadata;
        // Deadline for a committed review to be completed (Set in contract)
        uint256 commitmentDeadline;
        // The reviewers' decision on a particular submission
        Decision decision;
        // The status of the review
        ReviewStatus status;
    }

    // Status of a ThriveReview submission
    enum SubmissionStatus {
        NONE,
        PENDING,
        FINALIZED,
        DISPUTED,
        PAID_OUT
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
