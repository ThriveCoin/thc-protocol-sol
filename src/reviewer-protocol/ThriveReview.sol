// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


// @OpenZeppelin imports
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// ThriveProtocol imports
import {IThriveWorkerUnit} from "../interface/IThriveWorkerUnit.sol";
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
        require(idToSubmissions[submissionId_].status == SubmissionStatus.PENDING, "Submission is not in 'PENDING' status");
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

    // Amount of THRIVE submitters must reserve for reviewers
    uint256 public submitterReservedFunds;



    ////// USER VARIABLES //////

    // SUBMISSIONS

    Submission[] public submissions;

    // Mapping of user addresses to their submission IDs
    mapping(address => uint256[]) public userSubmissions;

    // Mapping of submission IDs to the Submission object
    mapping(uint256 => Submission) public idToSubmissions;


    // REVIEWS

    // Mapping of review IDs to the Review object
    mapping(uint256 => Review) public reviews;

    // Mapping of user addresses to their review IDs
    mapping(address => uint256[]) public userReviews; // mapping may not be needed

    // Mapping of counters for committed reviews per submission: submissionId => Number of committed reviews
    mapping(uint256 => uint256) public committedReviewsPerSubmissionCounter;

    // Mapping that checks if a user has committed to review a specific submission: userAddress => submissionId => bool
    mapping(address => mapping(uint256 => bool)) public userCommittedToReview;

    // Mapping of reviews per submission: submissionId => reviewId[]
    mapping(uint256 => uint256[]) public submissionReviews;

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



    // Scaler value for calculating ratios of accepted/rejected reviews
    uint256 constant SCALER = 10_000;


    /// @custom:oz-upgrades-unsafe-allow constructor    
    constructor() {
        _disableInitializers();
    }




    /**
     * @notice Initializes a newly created ThriveReview contract and calculates some internal logic.
     * @param reviewConfiguration_ Struct describing how reviews will be handled.
     * @param thriveReviewFactoryAddress_ Address of the ThriveReviewFactory contract.
     * @param badgeQueryContractAddress_ Address of the BadgeQuery contract.
     * @param owner_ Address of the creator of the work unit and ThriveReview contract.
     */
    function initialize(
        ReviewConfiguration memory reviewConfiguration_,
        address thriveReviewFactoryAddress_,
        address badgeQueryContractAddress_,
        address owner_
    ) external initializer {

        // Require for the agreement threshold to be above 50% percent
        require(reviewConfiguration_.agreementThreshold > 5000, "Agreement threshold must be above 50%");

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

        // Calculate amount of funds needed to reserve for reviewers (potentially max reviewers on submission)
        submitterReservedFunds = reviewConfiguration.reviewerReward * reviewConfiguration.maximumReviewsPerSubmission;


        /// EVENT
        ////////////////
    }



    /**
     * @notice Creates a new submission object.
     * @dev User must have the required badges to create a submission and reserve smoe amount of THRIVE in order to submit.
     * @param submission_ Struct containing the submission metadata.
     * @return submissionId ID of the newly created submission.
     */
    function createSubmission(
        Submission calldata submission_
    ) payable external onlyUserWithBadges(reviewConfiguration.submitterBadges) returns (uint256 submissionId) {

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

        // Require user enough funds to pay max number of reviewers
        require(msg.value >= submitterReservedFunds, "Insufficient funds to pay reviewers");



        // Fetch the submission ID and increment the counter
        submissionId = submissionCounter++;

        Submission storage submission = idToSubmissions[submissionId];

        // Save the submission to the `submissions` mapping
        submission.submissionMetadata = submission_.submissionMetadata;

        // Change the status of the submission to "PENDING"
        submission.status = SubmissionStatus.PENDING;

        // Save the contributor's address to be the msg.sender
        submission.contributor = _msgSender();

        // Save the submission ID to the user's submissions
        userSubmissions[_msgSender()].push(submissionId);


        // Emit event - fill data later
        emit SubmissionCreated(submissionId);
    }


    /**
     * @notice Updates a submission object on-chain.
     * @dev IS this function needed?
     * @param submissionMetadata_ New submission metadata.
     * @param submissionId_ Submission ID.
     */
    function updateSubmission (
        string calldata submissionMetadata_,
        uint256 submissionId_
    ) external 
        onlyUserWithBadges(reviewConfiguration.submitterBadges) 
        submissionPending(submissionId_)
    {

        // Require user to have submitted the submission
        require(idToSubmissions[submissionId_].contributor == _msgSender(), "Caller has not submitted this submission");
        
        // Require deadline for submissions has not passed
        require(block.timestamp <= reviewConfiguration.submissionDeadline, "Submission deadline has passed");

        // Require no reviews came in for this submission
        require(submissionReviews[submissionId_].length == 0, "Submission has reviews");



        // Save the edited submission to the `submissions` mapping
        idToSubmissions[submissionId_].submissionMetadata = submissionMetadata_;

        // Emit event - fill data later
        emit SubmissionUpdated(submissionId_);
    }


    /**
     * @notice User commits to review a specific submission.
     * @param submissionId_ ID of the submission.
     */
    function commitToReview(uint256 submissionId_) external 
        onlyUserWithBadges(reviewConfiguration.reviewerBadges) 
        submissionPending(submissionId_)
    {

        // Require that the user has not already committed to review the submission
        require(!userCommittedToReview[_msgSender()][submissionId_], "User has already committed to review this submission");

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

        // Change the status of the review to `COMMITTED`
        review.status = ReviewStatus.COMMITTED;



        // Make sure the user can't commit to review the same submission again
        userCommittedToReview[_msgSender()][submissionId_] = true;

        // Increment the counter of committed reviews
        committedReviewsPerSubmissionCounter[submissionId_]++;


        ///// EVENT
        //////////////
    }


    /**
     * @notice User creates the committed review with metadata and decision on submission.
     * @dev Previously created Review object is updated with new passed information.
     * @param review_ Review object containing the review metadata and decision.
     */
    function createReview(
        Review calldata review_
    ) external
        onlyUserWithBadges(reviewConfiguration.reviewerBadges) 
    {

        // Fetch the committed review from storage and copy to memory
        Review storage committedReview = reviews[review_.id];

        // Require user to have committed to the review
        require(committedReview.status == ReviewStatus.COMMITTED, "User has not committed to this review");

        // We can not use `submissionPending` modifier because user can commit to one submission ID and then bypass the modifier
        // by sending another one in review_ object. Here we use the submission ID previously committed to and saved in reviews mapping.
        // Require for the submission to be `PENDING`
        require(idToSubmissions[committedReview.submissionId].status == SubmissionStatus.PENDING, "Submission is not in 'PENDING' status");

        // Require user to be the committer to the review
        require(committedReview.reviewer == _msgSender(), "User is not the committer of this review");

        // Check that the deadline hasn't passed
        require(block.timestamp <= committedReview.deadline, "Review commitment deadline has passed");
        
        // Require that the review decision is either "ACCEPTED" or "REJECTED"
        require(review_.decision == Decision.ACCEPTED || review_.decision == Decision.REJECTED, "Review decision must be either 'ACCEPTED' or 'REJECTED'");
        
        // Require that the deadline to review has not passed
        require(block.timestamp <= reviewConfiguration.reviewDeadline, "Review deadline has passed");



        // Save the review to the `reviews` mapping
        committedReview.reviewMetadata = review_.reviewMetadata;

        // Save the reviewers' decision on the submission
        committedReview.decision = review_.decision;

        // Change the status of the review to `DONE`
        committedReview.status = ReviewStatus.DONE;



        // Get the review ID
        uint256 reviewId_ = committedReview.id;

        // Save the review ID to users' reviews array
        userReviews[_msgSender()].push(reviewId_); // @dev maybe this mapping is not needed at all



        // Save reviews of a submission
        submissionReviews[committedReview.submissionId].push(reviewId_);



        // HANDLE SUBMISSION OBJECT

        // Fetch the submission from storage
        Submission storage submission = idToSubmissions[committedReview.submissionId];

        // Update the review count on submission
        submission.reviewCount++;

        // Update the accepted/rejected review count on submission
        if (review_.decision == Decision.ACCEPTED) {
            submission.acceptedReviewsCount++;
        } else {
            submission.rejectedReviewsCount++;
        }


        // Reacka decision on submission automatically IF conditions are met
        _reachDecisionOnSubmission(committedReview.submissionId);


        //
        ////// EVENT
        ////////////////


        emit ReviewCreated(reviewId_);

    }


    /**
     * @notice Deletes pendings reviews if they are eligible for deleting.
     * @dev Occupied space is freed for new committed reviews. Anyone can delete it.
     * @param reviewIds_ Array of review IDs.
     */
    function deletePendingReviews(uint256[] calldata reviewIds_) external {
        for (uint256 i = 0; i < reviewIds_.length; i++) {
            deletePendingReview(reviewIds_[i]);
        }
    }


    /**
     * @notice Deletes a pending review if it is eligible for deleting.
     * @dev Occupied space is freed for new committed reviews. Anyone can delete it.
     * @param reviewId_ Review ID.
     */
    function deletePendingReview(uint256 reviewId_) public {

        // Require that the review is in the "COMMITTED" status
        require(reviews[reviewId_].status == ReviewStatus.COMMITTED, "Review is not in 'COMMITTED' status");
        
        // Require that the reviews' deadline has passed
        require(block.timestamp > reviews[reviewId_].deadline, "Review deadline has not passed");

        // Fetch the review data
        uint256 submissionId = reviews[reviewId_].submissionId;
        address reviewer = reviews[reviewId_].reviewer;

        // User un-committed from review
        userCommittedToReview[reviewer][submissionId] = false;

        // Decrement the counter of committed reviews
        committedReviewsPerSubmissionCounter[submissionId]--;

        // Delete the review from `reviews` mapping
        delete reviews[reviewId_];


        ////// EVENT

    }    

    /**
     * @notice Decision can be reached on a submission if all conditions are met.
     * @param submissionId_ Submission ID.
     */
    function reachDecisionOnSubmission(uint256 submissionId_) external 
        submissionPending(submissionId_)
    {
        _reachDecisionOnSubmission(submissionId_);
    }



    /**
     * @notice Decision is reached on a submission if conditions are met. WorkerUnit is called to payout the submitter.
     * @param submissionId_ Submission ID.
     */
    function _reachDecisionOnSubmission(uint256 submissionId_) internal {
        
        // Fetch the submission from storage
        Submission storage submission = idToSubmissions[submissionId_];


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

                // Distribute payouts to reviewers
                _payoutReviewersOnSubmission(submissionId_);

                // If work unit contract is set, confirm the submission on the work unit contract
                if (hasWorkerUnitContract()) {
                    IThriveWorkerUnit(workerUnitAddress).confirm(submission.contributor, submission.submissionMetadata);
                }

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


    /**
     * @notice Function for a badge holding user to manually make a decision on a submission when neither judgement reaches threshold OR not enough reviews came in (less than minimum).
     * @param submissionId_ Submission ID.
     * @param decision_ Decision on the submission.
     */
    function reachDecisionOnSubmissionAsBadge(uint256 submissionId_, Decision decision_) external 
        onlyUserWithBadges(reviewConfiguration.judgeBadges) 
        submissionPending(submissionId_)
    {

        // Fetch the submission from storage
        Submission storage submission = idToSubmissions[submissionId_];
                
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


        // Distribute payouts to reviewers
        _payoutReviewersOnSubmission(submissionId_);


        if (decision_ == Decision.ACCEPTED && hasWorkerUnitContract()) {

            // Confirm the work unit was accepted
            IThriveWorkerUnit(workerUnitAddress).confirm(submission.contributor, submission.submissionMetadata);
        }


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

    /**
     * @notice Distributes rewards to correct reviewers when the submission is finalized.
     * @param submissionId_ Submission ID.
     */
    function _payoutReviewersOnSubmission(uint256 submissionId_) internal {
        
        // Fetch the submission from storage
        Submission storage submission = idToSubmissions[submissionId_];

        // Require for the submission to be finalized
        require(submission.status == SubmissionStatus.FINALIZED, "Submission is not in 'FINALIZED' status");

        // Require that the rewards have not already been paid out for this submission
        require(!reviewerRewardsPaidOutForSubmission[submissionId_], "Rewards have already been paid out");


        // Update variable to show that the reviewers have claimed the reward
        reviewerRewardsPaidOutForSubmission[submissionId_] = true;

        // Fetch the reviews of the submission
        uint256[] memory reviewIds = submissionReviews[submissionId_];

        // Loop through the reviews for specific submission
        for (uint256 i = 0; i < reviewIds.length; i++) {

            // Fetch the review from storage
            Review storage review = reviews[reviewIds[i]];


            // Require that the user made the judgement that is the same as the final decision
            if (submission.decision == review.decision) {

                // Pay the reviewer
                (bool success, ) = review.reviewer.call{value: reviewConfiguration.reviewerReward}("");
                require(success);
            }
        }


        // Update the reserved funds for the submission
        _payoutSubmitterReservedFunds(submissionId_);



        ///// EVENTS
    }


    ////////  Ask Rilind what view functions should be implemented
    //////////////// 
    //////////////// 
    //////////////// 
    //////////////// 
    ////////////////



    /**
     * @notice Pays out the submission reserved funds to the submitter if his submission is ACCEPTED - otherwise return only a fraction of funds.
     * @param submissionId_ Submission ID.
     */
    function _payoutSubmitterReservedFunds(uint256 submissionId_) internal {

        // Fetch the submission from storage
        Submission storage submission = idToSubmissions[submissionId_];

        // Require for the submission to be finalized
        require(submission.status == SubmissionStatus.FINALIZED, "Submission is not in 'FINALIZED' status");


        // Check if the decision is ACCEPTED
        if (submission.decision == Decision.ACCEPTED) {

            // Pay the submitter
            (bool success, ) = submission.contributor.call{value: submitterReservedFunds}("");
            require(success);


            // Check if the decision is REJECTED
        } else if (submission.decision == Decision.REJECTED) {

            // Refund submitter funds that were reserved for reviewers who were incorrect in their reviews
            // and funds for reviews that were not made
            uint256 remainingAmountToPayout = reviewConfiguration.reviewerReward * submission.acceptedReviewsCount
                                                + reviewConfiguration.maximumReviewsPerSubmission - submission.reviewCount;

            // Pay the submitter
            (bool success, ) = submission.contributor.call{value: remainingAmountToPayout}("");
            require(success);

        }

    }



    /**
     * @notice Checks if this Review contract has a WorkerUnit tied to it or if its a standalone Review.
     * @return bool True if the contract has a WorkerUnit contract, false otherwise.
     */
    function hasWorkerUnitContract() public view returns (bool) {
        return workerUnitAddress != address(0);
    }


    /**
     * @notice Checks if the user has a pending submission.
     * @param user Address of the user.
     * @return bool True if the user has a pending submission, false otherwise.
     */
    function userHasPendingSubmission(address user) public view returns (bool) {

        uint256[] memory userSubmissionIds = userSubmissions[user];
        
        for (uint256 i = 0; i < userSubmissionIds.length; i++) {
            Submission memory submission = idToSubmissions[userSubmissionIds[i]];
            if (submission.status == SubmissionStatus.PENDING) {
                return true;
            }
        }

        return false;
    }


    /**
     * @notice Checks if the user has an ACCEPTED submission.
     * @param user Address of the user.
     * @return bool True if the user has an accepted submission, false otherwise.
     */
    function userHasAcceptedSubmission(address user) public view returns (bool) {

        uint256[] memory userSubmissionIds = userSubmissions[user];
        
        for (uint256 i = 0; i < userSubmissionIds.length; i++) {
            Submission memory submission = idToSubmissions[userSubmissionIds[i]];
            if (submission.decision == Decision.ACCEPTED) {
                return true;
            }
        }

        return false;
    }


    /**
     * @notice Function to retrieve funds reserved for reviewers sent during creation of the Review contract.
     * @dev Owner should be able to withdraw remaining funds if there are no pending submissions and the deadline of submitting is reached.
     */
    function retrieveFundsByOwner() external onlyOwner {

        // Owner should be able to withdraw remaining funds if there are no pending submissions and the deadline of submitting is reached.
        require(block.timestamp > reviewConfiguration.submissionDeadline, "Submission deadline has not passed");

        // Require there are no pending submissions



        // Do not send entire balance but only what is left after payouts
        uint256 leftAfterPayouts = address(this).balance; // @dev calculate this
        (bool success, ) = payable(_msgSender()).call{value: leftAfterPayouts}("");
        require(success);
    }


    /**
     * @notice MUST HAVE this function in order to receive THRIVE rewards for reviewers.
     */
    receive() external payable {}
}
