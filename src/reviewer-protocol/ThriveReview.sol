// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// @OpenZeppelin imports
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// ThriveProtocol imports
import "../interface/IThriveWorkUnit.sol";
import "./interface/IThriveReviewFactory.sol";
import "./interface/IThriveReview.sol";
import "../IBadgeQuery.sol";

/**
 * @title ThriveReview
 * @dev Contract for managing reviews.
 */
contract ThriveReview is OwnableUpgradeable, IThriveReview {

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
     * @dev Modifier that checks if the submission exists.
     * @param submissionId_ ID of the submission.
     */
    modifier submissionExists(uint256 submissionId_) {
        require(submissions[submissionId_].contributor != address(0), "Submission does not exist");
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


    ////// USER VARIABLES //////

    // SUBMISSIONS

    // Mapping of user addresses to their submission IDs
    mapping(address => uint256[]) public userSubmissions;

    // Mapping of submission IDs to the Submission object
    mapping(uint256 => Submission) public submissions;


    // REVIEWS

    // Mapping of user addresses to their review IDs
    mapping(address => uint256[]) public userReviews;

    // Mapping of review IDs to the Review object
    mapping(uint256 => Review) public reviews;

    // Mapping of reviews made to a single submission
    mapping(uint256 => uint256[]) public submissionReviews;


    /**
     * Events
     */

    // Event emitted when a submission is created
    event SubmissionCreated(uint256 submissionId);

    // Event emitted when a submission is updated
    event SubmissionUpdated(uint256 submissionId);

    // Event emitted when a review is created
    event ReviewCreated(uint256 reviewId);


    // @inheritdoc IThriveReview
    function initialize(
        IThriveReviewFactory.ReviewConfiguration memory reviewConfiguration_,
        address workUnitContractAddress_,
        address thriveReviewFactoryAddress_,
        address badgeQueryContractAddress_,
        address owner_
    ) external initializer {

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
        Submission calldata submission_
    ) external onlyUserWithBadges(reviewConfiguration.submitterBadges) {

        // Require that the work unit is still active
        require(IThriveWorkUnit(workUnitContractAddress).isActive() == true, "Work unit is not active");


        // Fetch the submission ID and increment the counter
        uint256 submissionId = submissionCounter++;

        // Save the submission to the `submissions` mapping
        submissions[submissionId] = submission_;

        // Change the status of the submission to "PENDING"
        submissions[submissionId].status = SubmissionStatus.PENDING;

        // Save the contributor's address to be the msg.sender
        submissions[submissionId].contributor = _msgSender();

        // Save the submission ID to the user's submissions
        userSubmissions[_msgSender()].push(submissionId);

        // Emit event - fill data later
        emit SubmissionCreated(submissionId);
    }


    function updateSubmission (
        Submission calldata editedSubmission_,
        uint256 submissionId_
    ) external onlyUserWithBadges(reviewConfiguration.submitterBadges) {

        // Require user to have submitted the submission
        require(hasUserSubmitted(_msgSender(), submissionId_), "User has not submitted this submission");
        // Require that the submission is in the "PENDING" status
        require(submissions[submissionId_].status == SubmissionStatus.PENDING, "Submission is not in PENDING status");
        // Require that the work unit is still active
        require(IThriveWorkUnit(workUnitContractAddress).isActive() == true, "Work unit is not active");



        // Save the edited submission to the `submissions` mapping
        submissions[submissionId_] = editedSubmission_;

        // Change the status of the submission to "PENDING"
        submissions[submissionId_].status = SubmissionStatus.PENDING;

        // Emit event - fill data later
        emit SubmissionUpdated(submissionId_);
    }


    // @inheritdoc IThriveReview
    function commitToReview(uint256 submissionId_) external 
        onlyUserWithBadges(reviewConfiguration.reviewerBadges) 
        submissionExists(submissionId_)
    {

        // Fetch the review ID and increment the counter
        uint256 reviewId = reviewCounter++;

        // Save the review to the `reviews` mapping
        Review storage review = reviews[reviewId];

        // Save the submission ID to the review
        review.submissionId = submissionId_;

        // Save the reviewers address in storage for later authentication
        review.reviewer = _msgSender();

        // Set the deadline for the review
        review.deadline = block.timestamp + reviewConfiguration.reviewCommitmentDeadline;

        // Change the status of the review to `COMMITED`
        review.status = ReviewStatus.COMMITED;
    }


    // @inheritdoc IThriveReview
    function createReview(
        Review calldata review_,
        uint256 reviewId_ // make sure user owns this reviewId_ hes commited to
    ) external 
        onlyUserWithBadges(reviewConfiguration.reviewerBadges) 
        submissionExists(review_.submissionId)
    {

        // Fetch the review from storage and copy to memory
        Review memory review = reviews[reviewId_];

        // Require user to be the committer of the review
        require(reviews[reviewId_].reviewer == _msgSender(), "User is not the committer of this review");
        // Require user to have commited to the review
        require(review.status == ReviewStatus.COMMITED, "User has not commited to this review");
        // Require user to create a review with the same submission ID they commited to
        require(review.submissionId == review_.submissionId, "User is not creating a review for the same submission they commited to");
        // Check that the deadline hasn't passed
        require(block.timestamp <= review.deadline, "Review deadline has passed");



        // Save the review to the `reviews` mapping
        reviews[reviewId_] = review_; // here he can change the .reviewer but maybe thats not a big deal ?

        // Save the review ID to the user's reviews
        userReviews[_msgSender()].push(reviewId_);

        // Save the review ID to the submission's reviews
        submissionReviews[review_.submissionId].push(reviewId_);

        // Change the status of the review to `DONE`
        reviews[reviewId_].status = ReviewStatus.DONE;

        // reach a decision at the end of each review
        // check if the threshold passed and reach a decision? Ask Rilind

        // Emit event - fill data later
        emit ReviewCreated(reviewId_);

    }

    // @inheritdoc IThriveReview
    function deletePendingReviews(uint256[] calldata reviewIds_) external {
        for (uint256 i = 0; i < reviewIds_.length; i++) {
            deletePendingReview(reviewIds_[i]);
        }
    }

    // @inheritdoc IThriveReview
    function deletePendingReview(uint256 reviewId_) public {

        // make sure the deadline has passed before deleting
        // write this only after writing the double linked list library

    }

    // @inheritdoc IThriveReview
    function _reachDecisionOnSubmission(uint256 submissionId_) internal {}
    // this is where we reach decisions on submissions, based on review configs


    // @inheritdoc IThriveReview
    function hasWorkUnitContract() public view returns (bool) {
        return workUnitContractAddress != address(0);
    }

    // @inheritdoc IThriveReview
    function hasUserSubmitted(address user, uint256 submissionId_) public view returns (bool) {

        uint256[] memory userSubmissionIds = userSubmissions[user];
        
        for (uint256 i = 0; i < userSubmissionIds.length; i++) {
            if (userSubmissionIds[i] == submissionId_) {
                return true;
            }
        }

        return false;
    }

    // @inheritdoc IThriveReview
    function retrieveFunds() external onlyOwner {}


    /**
     * @notice MUST HAVE this function in order to receive THRIVE rewards for reviewers.
     */
    receive() external payable {}
}
