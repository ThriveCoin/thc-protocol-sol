// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// @OpenZeppelin imports
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// ThriveProtocol imports
import "./interface/IThriveReviewFactory.sol";
import "./interface/IThriveReview.sol";
import "../IBadgeQuery.sol";

/**
 * @title ThriveReview
 * @dev Contract for managing reviews.
 */
contract ThriveReview is Initializable, OwnableUpgradeable, IThriveReview {

    /**
     * Modifiers
     */

    /**
     * @dev Modifier that checks if the user has the required badges.
     * @param badges Array of badges that the user must have.
     */
    modifier onlyUserWithBadges(bytes32[] memory badges) {
        for (uint256 i = 0; i < badges.length; i++) {
            // Require that user has the required badge
            require(IBadgeQuery(badgeQueryContractAddress).hasBadge(_msgSender(), badges[i]), "User does not have required badges");
        }
        _;
    }

    /**
     * Storage variables
     */

    // Review configuration - configuration/rules of the work unit review process
    IThriveReviewFactory.ReviewConfiguration public reviewConfiguration;

    // Address of the ThriveReviewFactory contract
    address public thriveReviewFactoryAddress;

    // Address of the work unit contract
    address public workUnitContractAddress;

    // Address of the BadgeQuery contract
    address public badgeQueryContractAddress;

    // Counter of submissions made to the contract
    uint256 public submissionCounter;

    // Counter of reviews made to the contract
    uint256 public reviewCounter;

    // @inheritdoc IThriveReview
    function initialize(
        IThriveReviewFactory.ReviewConfiguration memory reviewConfiguration_,
        address workUnitContractAddress_,
        address thriveReviewFactoryAddress_,
        address badgeQueryContractAddress_,
        address owner_
    ) external initializer {    // @dev Should this have an owner?

        // Set the ReviewConfiguration object
        reviewConfiguration = reviewConfiguration_;

        // Set the work unit contract address (optional: can be set later or not at all)
        workUnitContractAddress = workUnitContractAddress_;

        // Set the ThriveReviewFactory contract address
        thriveReviewFactoryAddress = thriveReviewFactoryAddress_;

        // Set the BadgeQuery contract address
        badgeQueryContractAddress = badgeQueryContractAddress_;

        // Set the owner of the contract
        __Ownable_init(owner_);
    }

    // @inheritdoc IThriveReview
    function createSubmission(
        Submission memory submission_
    ) external onlyUserWithBadges(submission_.reviewConfiguration.reviewerBadges) {
        // First make sure the submission is in accordance to the review configuration
        // Then make sure submission is made by a proper entity
        // Then make sure submission is not empty and follows some commong guidelines
        // Then save submission accordingly
    }

    // @inheritdoc IThriveReview
    function createReview(Review memory review_) external {}

    // @inheritdoc IThriveReview
    function commitToReview(uint256 reviewId_) external {
        // User commits to do a review of a certain submission
        // After a while anyone can delete his pending review if the does not complete it
    }

    // @inheritdoc IThriveReview
    function deletePendingReviews(uint256[] calldata reviewIds_) external {
        // Anyone can remove pending reviews that have passed some sort of time deadline
    }

    // @inheritdoc IThriveReview
    function deletePendingReview(uint256 reviewId_) public {
        // Anyone can remove pending review that have passed some sort of time deadline
    }

    // @inheritdoc IThriveReview
    function hasWorkUnitContract() public view returns (bool) {
        return workUnitContractAddress != address(0);
    }

    /**
     * @notice MUST HAVE this function in order to receive THRIVE rewards for reviewers.
     */
    receive() external payable {}
}
