// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


// @OpenZeppelin imports
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// ThriveProtocol imports
import {IThriveWorkerUnit} from "../interface/IThriveWorkerUnit.sol";
import {IThriveReviewFactory} from "./interface/IThriveReviewFactory.sol";
import {IThriveReview} from "./interface/IThriveReview.sol";
import {IBadgeQuery} from "../IBadgeQuery.sol";


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
            require(IBadgeQuery(badgeQueryContractAddress).hasBadge(_msgSender(), badges[i]), "User does not have required badge");
        }
        _;
    }

    /**
     * @dev Modifier that checks if the submission is in "PENDING" status.
     * @param submissionId_ ID of the submission.
     */
    modifier submissionPending(uint256 submissionId_) {
        require(submissions[submissionId_].status == SubmissionStatus.PENDING, "Submission is not in 'PENDING' status");
        _;
    }



    /**
     * Storage variables 
     * 
     * @dev Check later what storage variables are not actually needed.
     */

    // Review configuration - configuration/rules of the work unit review process
    ReviewConfiguration public reviewConfiguration;

    // Address of the ThriveReviewFactory contract
    address public thriveReviewFactoryAddress;

    // Address of the work unit contract
    address public workerUnitAddress;

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

    // Mapping of review IDs to the Review object
    mapping(uint256 => Review) public reviews;

    // Mapping of user addresses to their review IDs
    mapping(address => uint256[]) public userReviews;

    // Mapping of counters for commited reviews per submission: submissionId => Number of commited reviews
    mapping(uint256 => uint256) public committedReviewsPerSubmissionCounter;

    // Mapping of counters for reviews per submission: SubmissionId => Number of reviews
    mapping(uint256 => uint256) public reviewsPerSubmissionCounter;

    // Mapping that checks if a user has commited to review a specific submission: userAddress => submissionId => bool
    mapping(address => mapping(uint256 => bool)) public userCommitedToReview;

    // Mapping of reviews per submission: submissionId => reviewId[]
    mapping(uint256 => uint256[]) public submissionReviews; // @dev maybe this mapping is not needed at all

    // Mapping of user addresses to their submission reviews: userAddress => submissionId => true/false
    mapping(address => mapping(uint256 => bool)) public  userClaimedRewardForReview;

    // Mapping of review IDs to the reward claimed status
    mapping(uint256 => bool) public rewardsClaimedForReview;

    // Mapping of submission IDs to the reward claimed status
    mapping(uint256 => bool) public reviewerRewardsPaidOutForSubmission;




    /**
     * Events
     */

    // Event emitted when a submission is created
    event SubmissionCreated(uint256 submissionId);

    // Event emitted when a submission is updated
    event SubmissionUpdated(uint256 submissionId);

    // Event emitted when a review is created
    event ReviewCreated(uint256 reviewId);



    // Scaler value for calculating ratios accepted/rejected reviews
    uint256 constant SCALER = 10_000;


    /// @custom:oz-upgrades-unsafe-allow constructor    
    constructor() {
        _disableInitializers();
    }



    // @inheritdoc IThriveReview
    function initialize(
        ReviewConfiguration memory reviewConfiguration_,
        address thriveReviewFactoryAddress_,
        address badgeQueryContractAddress_,
        address owner_
    ) external initializer {

        // Set the ReviewConfiguration object/struct
        reviewConfiguration = reviewConfiguration_;

        // Set the work unit contract address (optional)
        workerUnitAddress = reviewConfiguration.workUnit;

        // Set the ThriveReviewFactory contract address
        thriveReviewFactoryAddress = thriveReviewFactoryAddress_;

        // Set the BadgeQuery contract address
        badgeQueryContractAddress = badgeQueryContractAddress_;

        // Set the owner of the contract
        __Ownable_init(owner_);

        // Make sure there is enough funds on worker unit contract to pay submissions - if there IS a worker unit contract
        if (reviewConfiguration.workUnit != address(0)) {
            
            uint256 maxSubmissions = reviewConfiguration.maximumSubmissions;
            uint256 maxSubmissionsByFundsOnWorkerUnit = IThriveWorkerUnit(workerUnitAddress).maxRewards() / IThriveWorkerUnit(workerUnitAddress).rewardAmount();
            
            require(maxSubmissions <= maxSubmissionsByFundsOnWorkerUnit, "Not enough funds on worker unit contract to pay submissions");
        }



        /// EVENT
        ////////////////
    }



    // @inheritdoc IThriveReview
    function createSubmission(
        Submission calldata submission_
    ) external onlyUserWithBadges(reviewConfiguration.submitterBadges) returns (uint256 submissionId) {

        // Require that the user does not have a `PENDING` submission
        require(!userHasPendingSubmission(_msgSender()), "User has a pending submission");

        // Require that the user does not have an already `ACCEPTED` submission
        require(!userHasAcceptedSubmission(_msgSender()), "User already has an accepted submission");

        // Require that the user has not reached the maximum number of submissions
        require(userSubmissions[_msgSender()].length < reviewConfiguration.maximumSubmissionsPerUser, "User has reached the maximum number of submissions");
        
        // Require that the maximum amount of submissions has not been reached
        require(submissionCounter < reviewConfiguration.maximumSubmissions, "Maximum amount of submissions has been reached");

        // Require deadline for submissions has not passed
        require(block.timestamp <= reviewConfiguration.submissionDeadline, "Submission deadline has passed");



        // Fetch the submission ID and increment the counter
        submissionId = submissionCounter++;

        // Save the submission to the `submissions` mapping
        submissions[submissionId].submissionMetadata = submission_.submissionMetadata;

        // Change the status of the submission to "PENDING"
        submissions[submissionId].status = SubmissionStatus.PENDING;

        // Save the contributor's address to be the msg.sender
        submissions[submissionId].contributor = _msgSender();

        // Save the submission ID to the user's submissions
        userSubmissions[_msgSender()].push(submissionId);



        // Emit event - fill data later
        emit SubmissionCreated(submissionId);
    }


    // @dev Should this function be implemented?
    // Problem is that the user can change the submissionMetadata while the review is ongoing
    function updateSubmission (
        Submission calldata editedSubmission_,
        uint256 submissionId_
    ) external 
        onlyUserWithBadges(reviewConfiguration.submitterBadges) 
        submissionPending(submissionId_)
    {

        // Require user to have submitted the submission
        require(submissions[submissionId_].contributor == _msgSender(), "Caller has not submitted this submission");
        
        // Require deadline for submissions has not passed
        require(block.timestamp <= reviewConfiguration.submissionDeadline, "Submission deadline has passed");



        // Save the edited submission to the `submissions` mapping
        submissions[submissionId_].submissionMetadata = editedSubmission_.submissionMetadata;

        // Emit event - fill data later
        emit SubmissionUpdated(submissionId_);
    }


    // @inheritdoc IThriveReview
    function commitToReview(uint256 submissionId_) external 
        onlyUserWithBadges(reviewConfiguration.reviewerBadges) 
        submissionPending(submissionId_)
    {

        // Require that the user has not already commited to review the submission
        require(!userCommitedToReview[_msgSender()][submissionId_], "User has already committed to review this submission");

        // Require that maximum amount of commits to review has not been reached
        require(committedReviewsPerSubmissionCounter[submissionId_] < reviewConfiguration.maximumReviewsPerSubmission, "Maximum amount of commits to review has been reached");

        // Require that the deadline to review has not passed
        require(block.timestamp <= reviewConfiguration.reviewDeadline, "Review deadline has passed");



        // Fetch the review ID and increment the counter
        uint256 reviewId = reviewCounter++;

        // Save the review to the `reviews` mapping
        Review storage review = reviews[reviewId];

        // Save the submission ID to the review
        review.id = reviewId;

        // Save the submission ID to the review
        review.submissionId = submissionId_;

        // Save the reviewers address in storage for later authentication
        review.reviewer = _msgSender();

        // @dev Should we make sure the reviewer is not the same user as the contributor?

        // Set the deadline for the review
        review.deadline = block.timestamp + reviewConfiguration.reviewCommitmentDeadline;

        // Change the status of the review to `COMMITED`
        review.status = ReviewStatus.COMMITED;



        // Make sure the user can't commit to review the same submission again
        userCommitedToReview[_msgSender()][submissionId_] = true;

        // Increment the counter of committed reviews
        committedReviewsPerSubmissionCounter[submissionId_]++;


        ///// EVENT
        //////////////
    }


    // @inheritdoc IThriveReview
    function createReview(
        Review calldata review_,
        uint256 reviewId_
    ) external 
        onlyUserWithBadges(reviewConfiguration.reviewerBadges) 
    {

        // Fetch the commited review from storage and copy to memory
        Review memory commitedReview = reviews[reviewId_];

        // Require user to have commited to the review
        require(commitedReview.status == ReviewStatus.COMMITED, "User has not commited to this review");

        // Require for the submission to be `PENDING`
        require(submissions[commitedReview.submissionId].status == SubmissionStatus.PENDING, "Submission is not in 'PENDING' status");

        // Require user to be the committer to the review
        require(commitedReview.reviewer == _msgSender(), "User is not the committer of this review");

        // Require that maximum amount reviews per submission has not been reached
        require(reviewsPerSubmissionCounter[review_.submissionId] < reviewConfiguration.maximumReviewsPerSubmission, "Maximum amount of commits to review has been reached");
        // We can remove this if maxCommitedPerSubmission == maxReviewsPerSubmission

        // Check that the deadline hasn't passed
        require(block.timestamp <= commitedReview.deadline, "Review commitment deadline has passed");
        
        // Require that the review decision is either "ACCEPTED" or "REJECTED"
        require(review_.decision == Decision.ACCEPTED || review_.decision == Decision.REJECTED, "Review decision must be either 'ACCEPTED' or 'REJECTED'");
        
        // Require that the deadline to review has not passed
        require(block.timestamp <= reviewConfiguration.reviewDeadline, "Review deadline has passed");



        // Save the review to the `reviews` mapping
        reviews[reviewId_].reviewMetadata = review_.reviewMetadata;

        // Save the reviewers' decision on the submission
        reviews[reviewId_].decision = review_.decision;

        // Save the review ID to the user's reviews
        userReviews[_msgSender()].push(reviewId_); // @dev maybe this mapping is not needed at all

        // Change the status of the review to `DONE`
        reviews[reviewId_].status = ReviewStatus.DONE;

        // Increment the counter of reviews
        reviewsPerSubmissionCounter[commitedReview.submissionId]++;


        // @dev 
        // Should we decrement the counter of committed reviews here to open up space for other commits?
        // Doesn't make a lot of sense, but it "speeds up" the process of reviewing.
        // This would make reviewing a "who's faster" contests, which is maybe not good.
        //
        // committedReviewsPerSubmissionCounter[review_.submissionId]--;


        // Save reviews of a submission
        submissionReviews[commitedReview.submissionId].push(reviewId_); // @dev maybe this mapping is not needed at all



        // HANDLE SUBMISSION OBJECT

        // Fetch the submission from storage
        Submission storage submission = submissions[commitedReview.submissionId];

        // Update the review count on submission
        submission.reviewCount++;

        // Update the accepted/rejected review count on submission
        if (review_.decision == Decision.ACCEPTED) {
            submission.acceptedReviewsCount++;
        } else {
            submission.rejectedReviewsCount++;
        }


        // Reacka decision on submission automatically IF conditions are met
        _reachDecisionOnSubmission(commitedReview.submissionId);


        //
        ////// EVENT
        ////////////////


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

        // Require that the review is in the "COMMITED" status
        require(reviews[reviewId_].status == ReviewStatus.COMMITED, "Review is not in 'COMMITED' status");
        
        // Require that the reviews' deadline has passed
        require(block.timestamp > reviews[reviewId_].deadline, "Review deadline has not passed");

        // Fetch the review data
        uint256 submissionId = reviews[reviewId_].submissionId;
        address reviewer = reviews[reviewId_].reviewer;

        // User un-committed from review
        userCommitedToReview[reviewer][submissionId] = false;

        // Decrement the counter of committed reviews
        committedReviewsPerSubmissionCounter[submissionId]--;

        // Delete the review from `reviews` mapping
        delete reviews[reviewId_];


        ////// EVENT

    }    

    // @inheritdoc IThriveReview
    function reachDecisionOnSubmission(uint256 submissionId_) external 
        submissionPending(submissionId_)
    {
        _reachDecisionOnSubmission(submissionId_);
    }



    // @inheritdoc IThriveReview
    function _reachDecisionOnSubmission(uint256 submissionId_) internal {
        
        // Fetch the submission from storage and copy to memory
        Submission storage submission = submissions[submissionId_];

        // We can put this "if statement" below as a require if this function is not called automatically on createReview function.

        // Check if the submission has enough reviews to reach a decision
        if (submission.reviewCount >= reviewConfiguration.minimumReviews) {

            // Calculate the ratio of accepted reviews
            uint256 acceptedReviews = submission.acceptedReviewsCount;
            uint256 acceptedRatio = (acceptedReviews * SCALER) / submission.reviewCount;

            // Calculate the ratio of rejected reviews
            uint256 rejectedReviews = submission.rejectedReviewsCount;
            uint256 rejectedRatio = (rejectedReviews * SCALER) / submission.reviewCount;

            // Check if the ratio is above the agreement threshold
            if (acceptedRatio >= reviewConfiguration.agreementThreshold) {

                // Confirm the submission is no longer PENDING
                submission.status = SubmissionStatus.FINALIZED;

                // Submission is ACCEPTED
                submission.decision = Decision.ACCEPTED;

                // If work unit contract is set, confirm the submission on the work unit contract
                if (hasWorkerUnitContract()) {
                    IThriveWorkerUnit(workerUnitAddress).confirm(submission.contributor, submission.submissionMetadata);
                }

                // Distribute payouts to reviewers
                _payoutReviewersOnSubmission(submissionId_);

            } // Check if the ratio is above the agreement threshold
            else if (rejectedRatio >= reviewConfiguration.agreementThreshold) {

                // Confirm the submission is no longer PENDING
                submission.status = SubmissionStatus.FINALIZED;

                // Submission is REJECTED
                submission.decision = Decision.REJECTED;

                // Distribute payouts to reviewers
                _payoutReviewersOnSubmission(submissionId_);
                
            }
        }


        /////// EVENT
        //////////////
    }


    // @inheritdoc IThriveReview
    function reachDecisionOnSubmissionAsBadge(uint256 submissionId_, Decision decision_) external 
        onlyUserWithBadges(reviewConfiguration.judgeBadges) 
        submissionPending(submissionId_)
    {

        // Fetch the submission from storage
        Submission storage submission = submissions[submissionId_];
                
        // User with badge can only make a final decision when the submission has NOT reached the agreement threshold on either ACCEPTED or REJECTED with max reviews
        // OR when the review deadline has passed and the submission has not reached a decision
        // Allowing badge to make a final decision when the review deadline has passed may, at first, seem to give the badge too much power -
        // but we also disallow reviewing after the deadline, so its not like the badge is front-running the reviewers/decision.
        require(
            submission.reviewCount >= reviewConfiguration.maximumReviewsPerSubmission || 
            block.timestamp > reviewConfiguration.reviewDeadline,
            "Submission has not reached requirements for a final decision as badge"
        );

        // Require the decision is either "ACCEPTED" or "REJECTED"
        require(decision_ == Decision.ACCEPTED || decision_ == Decision.REJECTED, "Decision must be either 'ACCEPTED' or 'REJECTED'");

        // Confirm the submission is FINALIZED
        submission.status = SubmissionStatus.FINALIZED;

        // Submission is ACCEPTED or REJECTED
        submission.decision = decision_;

        if (decision_ == Decision.ACCEPTED && hasWorkerUnitContract()) {

            // Confirm the work unit was accepted
            IThriveWorkerUnit(workerUnitAddress).confirm(submission.contributor, submission.submissionMetadata);
        }

        // Distribute payouts to reviewers
        _payoutReviewersOnSubmission(submissionId_);


        ////////
        //////// EVENT
    }

    /* Commented out because we will distribute rewards for reviewers when the submission is finalized automatically
    // @inheritdoc IThriveReview
    function claimReviewerRewards(uint256[] calldata reviewIds_) external {
        for (uint256 i = 0; i < reviewIds_.length; i++) {
            claimReviewerReward(reviewIds_[i]);
        }
    }


    // @inheritdoc IThriveReview
    function claimReviewerReward(uint256 reviewId_) public {

        // Require that the user has not already claimed the reward
        require(!rewardsClaimedForReview[reviewId_], "User has already claimed the reward");

        // Fetch the review from storage
        Review storage review = reviews[reviewId_];

        // Require user submitted the review
        require(review.reviewer == _msgSender(), "User has not submitted this review");

        // Fetch the submission from storage
        Submission storage submission = submissions[review.submissionId];

        // Require for the submission to be finalized
        require(submission.status == SubmissionStatus.FINALIZED, "Submission is not in 'FINALIZED' status");

        // Require that the user made the judgement that is the same as the final decision
        if(submission.decision == review.decision) {

            // Update variable to show that the user has claimed the reward
            rewardsClaimedForReview[reviewId_] = true;

            // Pay the reviewer
            (bool success, ) = _msgSender().call{value: reviewConfiguration.reviewerReward}("");
            require(success);
        }


        ///// EVENTS
        //////////////
    }
    */

    // @inheritdoc IThriveReview
    function _payoutReviewersOnSubmission(uint256 submissionId_) internal {
        
        // Fetch the submission from storage
        Submission storage submission = submissions[submissionId_];

        // Fetch the reviews of the submission
        uint256[] memory reviewIds = submissionReviews[submissionId_];

        // Loop through the reviews
        for (uint256 i = 0; i < reviewIds.length; i++) {

            // Fetch the review from storage
            Review storage review = reviews[reviewIds[i]];

            // Require that the rewards have not already been paid out for this submission
            require(!reviewerRewardsPaidOutForSubmission[submissionId_], "Rewards have already been paid out");

            // Require that the user made the judgement that is the same as the final decision
            if (submission.decision == review.decision) {

                // Pay the reviewer
                (bool success, ) = review.reviewer.call{value: reviewConfiguration.reviewerReward}("");
                require(success);
            }
        }

        // Update variable to show that the reviewers have claimed the reward
        reviewerRewardsPaidOutForSubmission[submissionId_] = true;

        ///// EVENTS
    }


    ////////  Ask Rilind what view functions should be implemented
    //////////////// 
    //////////////// 
    //////////////// 
    //////////////// 
    ////////////////




    // @inheritdoc IThriveReview
    function hasWorkerUnitContract() public view returns (bool) {
        return workerUnitAddress != address(0);
    }


    // @inheritdoc IThriveReview
    function userHasPendingSubmission(address user) public view returns (bool) {

        uint256[] memory userSubmissionIds = userSubmissions[user];
        
        for (uint256 i = 0; i < userSubmissionIds.length; i++) {
            Submission memory submission = submissions[userSubmissionIds[i]];
            if (submission.status == SubmissionStatus.PENDING) {
                return true;
            }
        }

        return false;
    }

    // @inheritdoc IThriveReview
    function userHasAcceptedSubmission(address user) public view returns (bool) {

        uint256[] memory userSubmissionIds = userSubmissions[user];
        
        for (uint256 i = 0; i < userSubmissionIds.length; i++) {
            Submission memory submission = submissions[userSubmissionIds[i]];
            if (submission.decision == Decision.ACCEPTED) {
                return true;
            }
        }

        return false;
    }


    // @inheritdoc IThriveReview
    function retrieveFunds() external onlyOwner {
        // @dev
        // This should be time-restricted so that the owner can't just take the funds whenever they want.
        // require(block.timestamp > unlockTime, "Funds are locked");
        (bool success, ) = payable(_msgSender()).call{value: address(this).balance}("");
        require(success);
    }


    /**
     * @notice MUST HAVE this function in order to receive THRIVE rewards for reviewers.
     */
    receive() external payable {}
}
