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
 * @dev Contract for reviewer protocol.
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
        require(idToSubmission[submissionId_].status == SubmissionStatus.PENDING, "Submission is not in 'PENDING' status");
        _;
    }


    /**
     * @dev Modifier that checks if the user is involved in the submission either as contributor or reviewer.
     * @param submissionId_ ID of the submission.
     */
    modifier onlyInvolvedInSubmission(uint256 submissionId_) {
        require(userInvolvedInSubmission[_msgSender()][submissionId_], "User is not involved in this submission");
        _;
    }




    /**
     * Storage variables 
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

    // Total amount of failed distribution funds
    uint256 public failedDistributionTotalAmount;



    ////// USER VARIABLES //////

    // SUBMISSIONS

    Submission[] public submissions;

    // Mapping of user addresses to their submission IDs
    mapping(address => uint256[]) public userSubmissions;

    // Mapping of submission IDs to the Submission object
    mapping(uint256 => Submission) public idToSubmission;


    // REVIEWS

    // Mapping of review IDs to the Review object
    mapping(uint256 => Review) public reviews;

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

    // Mapping of failed distribution amounts for reviewers so users can claim manually: userAddress => THRIVE amount
    mapping(address => uint256) public failedDistributionAmounts;

    // Mapping which describes if the user/address is involved in any submission either as a contributor or reviewer: userAddress => submissionId => true/false
    mapping(address => mapping(uint256 => bool)) public userInvolvedInSubmission;




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



    ////////////////////////////////////////////////////////////////////
    //                      SUBMISSION FUNCTIONS                      //
    ////////////////////////////////////////////////////////////////////



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

        Submission storage submission = idToSubmission[submissionId];

        // Save the submission ID to the submission
        submission.id = submissionId;

        // Save the submission to the `submissions` mapping
        submission.submissionMetadata = submission_.submissionMetadata;

        // Change the status of the submission to "PENDING"
        submission.status = SubmissionStatus.PENDING;

        // Save the contributor's address to be the msg.sender
        submission.contributor = _msgSender();

        // Set the deadline for the reviews
        submission.reviewDeadline = uint64(block.timestamp + reviewConfiguration.reviewDeadlinePeriod);

        
        // Save the submission ID to the user's submissions
        userSubmissions[_msgSender()].push(submissionId);

        // Save the submission to the `submissions` array
        submissions.push(submission);

        // Save the users' involvement in the submission: contributor
        userInvolvedInSubmission[_msgSender()][submissionId] = true;


        // Emit event - fill data later
        emit SubmissionCreated(submissionId);
    }


    /**
     * @notice Updates a submission object on-chain.
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
        require(idToSubmission[submissionId_].contributor == _msgSender(), "Caller has not submitted this submission");
        
        // Require deadline for submissions has not passed
        require(block.timestamp <= reviewConfiguration.submissionDeadline, "Submission deadline has passed");

        // Require no reviews came in for this submission
        require(submissionReviews[submissionId_].length == 0, "Submission has reviews");



        // Save the edited submission to the `submissions` mapping
        idToSubmission[submissionId_].submissionMetadata = submissionMetadata_;

        // Emit event - fill data later
        emit SubmissionUpdated(submissionId_);
    }




    ////////////////////////////////////////////////////////////////////
    //                       REVIEW FUNCTIONS                         //
    ////////////////////////////////////////////////////////////////////



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
        require(block.timestamp <= idToSubmission[submissionId_].reviewDeadline, "Review deadline has passed");



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

        // Set the deadline for the review
        review.deadline = block.timestamp + reviewConfiguration.reviewCommitmentPeriod;

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
        require(idToSubmission[committedReview.submissionId].status == SubmissionStatus.PENDING, "Submission is not in 'PENDING' status");

        // Require user to be the committer to the review
        require(committedReview.reviewer == _msgSender(), "User is not the committer of this review");

        // Require that the commitment deadline has not passed
        require(block.timestamp <= committedReview.deadline, "Review commitment deadline has passed");
        
        // Require that the review decision is either "ACCEPTED" or "REJECTED"
        require(review_.decision == Decision.ACCEPTED || review_.decision == Decision.REJECTED, "Review decision must be either 'ACCEPTED' or 'REJECTED'");
        
        // Require that the deadline to review this submission has not passed
        require(block.timestamp <= idToSubmission[committedReview.submissionId].reviewDeadline, "Review deadline has passed");



        // Save the review to the `reviews` mapping
        committedReview.reviewMetadata = review_.reviewMetadata;

        // Save the reviewers' decision on the submission
        committedReview.decision = review_.decision;

        // Change the status of the review to `DONE`
        committedReview.status = ReviewStatus.DONE;



        // Get the review ID
        uint256 reviewId_ = committedReview.id;

        // Save reviews of a submission
        submissionReviews[committedReview.submissionId].push(reviewId_);

        // Save the user's involvement in the submission: reviewer
        userInvolvedInSubmission[_msgSender()][committedReview.submissionId] = true;



        // HANDLE SUBMISSION OBJECT

        // Fetch the submission from storage
        Submission storage submission = idToSubmission[committedReview.submissionId];

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


    ////////////////////////////////////////////////////////////////////
    //                 SUBMISSION DECISION FUNCTIONS                  //
    ////////////////////////////////////////////////////////////////////



    /**
     * @notice Decision is reached on a submission if conditions are met. WorkerUnit is called to payout the submitter.
     * @param submissionId_ Submission ID.
     */
    function _reachDecisionOnSubmission(uint256 submissionId_) internal {
        
        // Fetch the submission from storage
        Submission storage submission = idToSubmission[submissionId_];


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

                // Start dispute period
                submission.disputeDeadline = uint64(block.timestamp + 2 days);


            } // Check if the ratio is above the agreement threshold
            else if (rejectedRatio >= reviewConfiguration.agreementThreshold) {

                // Confirm the submission is no longer PENDING
                submission.status = SubmissionStatus.FINALIZED;

                // Submission is REJECTED
                submission.decision = Decision.REJECTED;

                // Start dispute period
                submission.disputeDeadline = uint64(block.timestamp + 2 days);
                
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
        Submission storage submission = idToSubmission[submissionId_];
                
        // User with badge can only make a final decision when the submission has NOT reached the agreement threshold on either ACCEPTED or REJECTED with max reviews
        // OR when the review deadline has passed and the submission has not reached a decision
        // Allowing badge to make a final decision when the review deadline has passed may, at first, seem to give the badge too much power -
        // but we also disallow reviewing after the deadline, so its not like the badge is front-running the reviewers/decision.
        require(
            submission.reviewCount >= reviewConfiguration.maximumReviewsPerSubmission || 
            block.timestamp > submission.reviewDeadline,
            "Submission has not reached requirements for a final decision as badge"
        );

        // Require the decision is either "ACCEPTED" or "REJECTED"
        require(decision_ == Decision.ACCEPTED || decision_ == Decision.REJECTED, "Decision must be either 'ACCEPTED' or 'REJECTED'");


        // Confirm the submission is FINALIZED
        submission.status = SubmissionStatus.FINALIZED;

        // Submission is ACCEPTED or REJECTED
        submission.decision = decision_;

        // Start dispute period
        submission.disputeDeadline = uint64(block.timestamp + 2 days);



        ////////
        //////// EVENT
    }


    ////////////////////////////////////////////////////////////////////
    //                 FUNDS MANAGEMENT FUNCTIONS                     //
    ////////////////////////////////////////////////////////////////////


    /**
     * @notice Allows reviewers to claim their rewards if the automatic payout/distribution failed.
     * @dev This function is needed because the automatic distribution payout might fail due to various reasons.
     */
    function claimFailedDistributionFunds() external {

        // Fetch the amount of failed distribution funds
        uint256 amount = failedDistributionAmounts[_msgSender()];

        // Require that the user has failed distribution funds
        require(amount > 0, "User has no failed distribution funds");

        // Reset the failed distribution funds
        delete failedDistributionAmounts[_msgSender()];

        // Payout the user
        (bool success, ) = _msgSender().call{value: amount}("");
        require(success);



        // EMIT EVENT
    }



    /**
     * @notice Function to retrieve funds reserved for reviewers sent during creation of the Review contract.
     * @dev Owner should be able to withdraw remaining funds if all submissions are paid out and the deadline of submitting is reached.
     */
    function retrieveFundsByOwner() external onlyOwner {

        // Owner should be able to withdraw remaining funds if there are no pending submissions and the deadline of submitting is reached.
        require(block.timestamp > reviewConfiguration.submissionDeadline, "Submission deadline has not passed");

        // Require all submissions are PAID_OUT
        require(allSubmissionsPaidOut(), "Not all submissions are paid out");


        // Send entire balance but leave the failed distribution funds to be claimable
        uint256 leftAfterPayouts = address(this).balance - failedDistributionTotalAmount;

        // Transfer funds to owner
        (bool success, ) = payable(_msgSender()).call{value: leftAfterPayouts}("");
        require(success);


        //// EVENT
    }




    ////////////////////////////////////////////////////////////////////
    //                      DISPUTE FUNCIONALITY                      //
    ////////////////////////////////////////////////////////////////////



    /**
     * @notice Function to raise a dispute on a submission when user does not agree with final decision.
     * @param submissionId_ Submission ID.
     */
    function raiseDisputeOnSubmission(uint256 submissionId_) external onlyInvolvedInSubmission(submissionId_) {

        // Get the submission from storage
        Submission storage submission = idToSubmission[submissionId_];

        // @dev: Do we make sure the submitter raises dispute on rejected submissions and reviewers whose review decision does not match the final decision?
        // Discuss w Mijo first.
        
        // Require that the submission is in "FINALIZED" status
        require(submission.status == SubmissionStatus.FINALIZED, "Submission is not in 'FINALIZED' status");

        // Require for the time-limit on disputing for the submission to NOT have passed
        require(block.timestamp <= submission.disputeDeadline, "Dispute deadline has passed");


        // Put submission in "DISPUTED" status
        submission.status = SubmissionStatus.DISPUTED;


        // EMIT EVENT
    }


    /**
     * @notice Function for resolving disputes on submissions by user holding dispute badge.
     * @param submissionId_ Submission ID.
     * @param decision_ Decision on the submission.
     */
    function resolveDisputeOnSubmission(uint256 submissionId_, Decision decision_) external onlyUserWithBadges(reviewConfiguration.disputeResolverBadges) {

        // Fetch submission from storage
        Submission storage submission = idToSubmission[submissionId_];
        
        // Require for the submission to be in "DISPUTED" status
        require(submission.status == SubmissionStatus.DISPUTED, "Submission is not in 'DISPUTED' status");


        // Resolve the submission decision based on the resolvers' decision
        submission.decision = decision_;

        // Pay out reviewers
        _distributeRewardsForSubmission(submissionId_);


        //// EVENT
    }

    
    /**
     * @notice Function for canceling disputes on submissions. Distributes rewards to reviewers based on current decision. Only callable by owner.
     * @param submissionId_ Submission ID.
     */
    function cancelDisputeOnSubmission(uint256 submissionId_) external onlyOwner {

        // Fetch submission from storage
        Submission memory submission = idToSubmission[submissionId_];

        // Require for this submission to be "DISPUTED"
        require(submission.status == SubmissionStatus.DISPUTED, "Submission is not in 'DISPUTED' status");

        // Require for the time-limit on disputing for the submission to have passed + some buffer time so that owner does not cancel the dispute too early
        require(block.timestamp > submission.disputeDeadline + 1 days, "Dispute deadline has not passed");


        // Pay out reviewers
        _distributeRewardsForSubmission(submissionId_);


        //// EVENT
    }



    /**
     * @notice Function for distributing payouts to reviewers for non-disputed submissions.
     * @param submissionIds_ Array of submission IDs.
     */
    function distributePayoutsForNonDisputedSubmissions(uint256[] calldata submissionIds_) external {
        for (uint256 i = 0; i < submissionIds_.length; i++) {
            distributePayoutsForNonDisputedSubmission(submissionIds_[i]);
        }
    }



    /**
     * @notice Function for distributing payouts to reviewers for non-disputed submissions.
     * @param submissionId_ Submission ID.
     */
    function distributePayoutsForNonDisputedSubmission(uint256 submissionId_) public {

        // Fetch submission from storage
        Submission memory submission = idToSubmission[submissionId_];

        // Require for the submission to be in "FINALIZED" status
        require(submission.status == SubmissionStatus.FINALIZED, "Submission is not in 'FINALIZED' status");

        // Require for the dispute time-limit to have passed
        require(block.timestamp > submission.disputeDeadline, "Dispute deadline has not passed");
        

        // Pay out reviewers
        _distributeRewardsForSubmission(submissionId_);


        //////// EVENT
    }




    ////////////////////////////////////////////////////////////////////
    //                          PAYOUT LOGIC                          //
    ////////////////////////////////////////////////////////////////////


    /**
     * @notice Distributes rewards to correct reviewers when the submission is finalized.
     * @param submissionId_ Submission ID.
     */
    function _distributeRewardsForSubmission(uint256 submissionId_) internal {
        
        // Fetch the submission from storage
        Submission storage submission = idToSubmission[submissionId_];

        // Require that the submission is in "FINALIZED" or "DISPUTED" status
        require(submission.status == SubmissionStatus.FINALIZED || submission.status == SubmissionStatus.DISPUTED, "Submission is not in 'FINALIZED' or 'DISPUTED' status");


        // Update submission status to "PAID_OUT"
        submission.status = SubmissionStatus.PAID_OUT;

        // Fetch the reviews of the submission
        uint256[] memory reviewIds = submissionReviews[submissionId_];

        // Loop through the reviews for specific submission
        for (uint256 i = 0; i < reviewIds.length; i++) {

            // Fetch the review from storage
            Review memory review = reviews[reviewIds[i]];


            // Require that the user made the judgement that is the same as the final decision
            if (submission.decision == review.decision) {

                // Pay the reviewer - Do not revert on failure because we want to continue with the payouts. 
                // Those whose payouts failed will be able to claim manually.
                (bool success, ) = review.reviewer.call{value: reviewConfiguration.reviewerReward}("");
                if (!success) {
                    failedDistributionAmounts[review.reviewer] += reviewConfiguration.reviewerReward;
                    failedDistributionTotalAmount += reviewConfiguration.reviewerReward;
                }
            }
        }



        // Pay out and update the reserved funds for the submission
        _payoutSubmitterReservedFunds(submissionId_);


        // If there is a WorkerUnit, pay out the contributor on the WorkerUnit
        if (submission.decision == Decision.ACCEPTED && hasWorkerUnitContract()) {

            // Confirm the work unit was accepted
            IThriveWorkerUnit(workerUnitAddress).confirm(submission.contributor, submission.submissionMetadata);
        }




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
        Submission memory submission = idToSubmission[submissionId_];

        // Check if the decision is ACCEPTED
        if (submission.decision == Decision.ACCEPTED) {

            // Refund the submitter - Do not revert on failure because we want to continue with the payouts. 
            // Those whose payouts failed will be able to claim manually.
            (bool success, ) = submission.contributor.call{value: submitterReservedFunds}("");
            if (!success) {
                failedDistributionAmounts[submission.contributor] += submitterReservedFunds;
                failedDistributionTotalAmount += submitterReservedFunds;
            }


            // Check if the decision is REJECTED
        } else if (submission.decision == Decision.REJECTED) {

            // Refund submitter funds that were reserved for reviewers who were incorrect in their reviews
            // and funds for reviews that were not made
            uint256 remainingAmountToPayout = reviewConfiguration.reviewerReward * submission.acceptedReviewsCount
                                                + reviewConfiguration.maximumReviewsPerSubmission - submission.reviewCount;

            // Refund the submitter - Do not revert on failure because we want to continue with the payouts. 
            // Those whose payouts failed will be able to claim manually.
            (bool success, ) = submission.contributor.call{value: remainingAmountToPayout}("");
            if (!success) {
                failedDistributionAmounts[submission.contributor] += remainingAmountToPayout;
                failedDistributionTotalAmount += remainingAmountToPayout;
            }

        }

    }



    
    ////////////////////////////////////////////////////////////////////
    //                          VIEW FUNCTIONS                        //
    ////////////////////////////////////////////////////////////////////


    /**
     * @notice Checks if the user has a pending submission.
     * @param user Address of the user.
     * @return bool True if the user has a pending submission, false otherwise.
     */
    function userHasPendingSubmission(address user) public view returns (bool) {

        uint256[] memory userSubmissionIds = userSubmissions[user];
        
        for (uint256 i = 0; i < userSubmissionIds.length; i++) {
            Submission memory submission = idToSubmission[userSubmissionIds[i]];
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
            Submission memory submission = idToSubmission[userSubmissionIds[i]];
            if (submission.decision == Decision.ACCEPTED) {
                return true;
            }
        }

        return false;
    }


    /**
     * @notice Checks if all submissions are paid out.
     * @return bool True if all submissions are paid out, false otherwise.
     */
    function allSubmissionsPaidOut() public view returns (bool) {

        for (uint256 i = 0; i < submissions.length; i++) {
            if (submissions[i].status != SubmissionStatus.PAID_OUT) {
                return false;
            }
        }

        return true;
    }

    
    /**
     * @notice Fetches the decision of a submission.
     * @return IThriveReview.Decision NONE/ACCEPTED/REJECTED.
     */
    function getSubmissionDecision(uint256 submissionId_) public view returns (Decision) {
        return idToSubmission[submissionId_].decision;
    }

    /**
     * @notice Fetches the status of a submission.
     * @return IThriveReview.SubmissionStatus NONE/PENDING/FINALIZED/DISPUTED/PAID_OUT.
     */
    function getSubmissionStatus(uint256 submissionId_) public view returns (SubmissionStatus) {
        return idToSubmission[submissionId_].status;
    }



    /**
     * @notice Checks if this Review contract has a WorkerUnit tied to it or if its a standalone Review.
     * @return bool True if the contract has a WorkerUnit contract, false otherwise.
     */
    function hasWorkerUnitContract() public view returns (bool) {
        return workerUnitAddress != address(0);
    }




    /**
     * @notice MUST HAVE this function in order to receive THRIVE rewards for reviewers.
     */
    receive() external payable {}
}
