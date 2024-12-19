// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// @OpenZeppelin imports
import "@openzeppelin/contracts/access/Ownable.sol";

// ThriveProtocol imports
import "./interface/IThriveReviewFactory.sol";
import "./interface/IThriveReview.sol";

/**
 * @title ThriveReview
 * @dev Contract for managing reviews.
 */
contract ThriveReview is Ownable, IThriveReview {
    /**
     * Storage variables
     */

    // Review configuration - configuration/rules of the work unit review process
    IThriveReviewFactory.ReviewConfiguration public reviewConfiguration;

    // Address of the work unit contract
    address public workUnitContractAddress;

    // Counter of submissions made to the contract
    uint256 public submissionCounter;

    // Counter of reviews made to the contract
    uint256 public reviewCounter;

    constructor(
        IThriveReviewFactory.ReviewConfiguration memory reviewConfiguration_,
        address workUnitContractAddress_,
        address owner_
    ) Ownable(owner_) {
        workUnitContractAddress = workUnitContractAddress_;
        reviewConfiguration = reviewConfiguration_;
    }

    // @inheritdoc IThriveReview
    function createSubmission(
        Submission memory submission_
    ) external /* onlyUserWithSomeBadge */ {
        // First make sure the submission is in accordance to the review configuration
        // Then make sure submission is made by a proper entity
        // Then make sure submission is not empty and follows some commong guidelines
        // Then save submission accordingly
    }

    // @inheritdoc IThriveReview
    function createReview(Review memory review_) external {}

    // @inheritdoc IThriveReview
    function deletePendingReviews(uint256[] calldata reviewIds_) external {
        // Anyone can remove pending reviews that have passed some sort of time deadline
    }

    // @inheritdoc IThriveReview
    function deletePendingReview(uint256 reviewId_) public {
        // Anyone can remove pending review that have passed some sort of time deadline
    }

    // @inheritdoc IThriveReview
    function commitToReview(uint256 reviewId_) external {
        // User commits to do a review of a certain submission
        // After a while anyone can delete his pending review if the does not complete it
    }
}
