// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


// @OpenZeppelin imports
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


// ThriveProtocol imports
import {IThriveReview} from "./interface/IThriveReview.sol";
import {IThriveReviewFactory} from "./interface/IThriveReviewFactory.sol";
import {IThriveWorkerUnit} from "../interface/IThriveWorkerUnit.sol";
import {IThriveWorkerUnitFactory} from "../interface/IThriveWorkerUnitFactory.sol";


/**
 * @title ThriveReviewFactory
 * @dev Factory contract for creating ThriveReview and/or ThriveWorkUnit contract instances.
 */
contract ThriveReviewFactory is
    OwnableUpgradeable,
    UUPSUpgradeable,
    IThriveReviewFactory
{


    /**
     * STORAGE VARIABLES
     */

    // Address of the ThriveWorkerUnitFactory contract
    address public thriveWorkerUnitFactory;

    // Address of the ThriveReview contract implementation
    address public thriveReviewContractImplementation;

    // Address of the BadgeQuery contract
    address public badgeQueryContractAddress;



    /**
     * EVENTS
     */

    /**
     * @notice Emitted when a new Review contract is created.
     * @param reviewContract Address of the review contract.
     */
    event ReviewContractCreated(address reviewContract);


    /**
     * @notice Initializes the contract with the provided addresses.
     * @param thriveWorkerUnitFactory_ Address of the ThriveWorkerUnitFactory contract.
     * @param thriveReviewContractImplementation_ Address of the ThriveReview contract implementation.
     * @param badgeQueryContractAddress_ Address of the BadgeQuery contract.
     * @param owner_ Owner address of this contract.
     */
    function initialize(
        address thriveWorkerUnitFactory_,
        address thriveReviewContractImplementation_,
        address badgeQueryContractAddress_,
        address owner_
    ) external initializer {

        // @dev add update function for this address?
        thriveWorkerUnitFactory = thriveWorkerUnitFactory_;

        // Save the implementation address for the ThriveReview contract
        thriveReviewContractImplementation = thriveReviewContractImplementation_;

        // Save the address of the BadgeQuery contract
        badgeQueryContractAddress = badgeQueryContractAddress_;

        // Initialize the contract with the provided owner
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();


        /// EVENTS
        //////////////
    }



    /**
     * @notice Creates new WorkerUnit and ThriveReview contracts.
     * @param workUnitArgs_ Struct containing args for properly initializing WorkUnit contract.
     * @param reviewConfiguration_ Struct containing args for the reviewing process.
     * @return Address of the newly created ThriveReview contract.
     */
    function createWorkUnitAndReviewContract(
        IThriveWorkerUnitFactory.WorkUnitArgs memory workUnitArgs_,
        IThriveReview.ReviewConfiguration memory reviewConfiguration_
    ) external payable returns (address, address) {

        // Require enough funds are sent to payout the reward for reviewers
        require(msg.value >= reviewConfiguration_.reviewerRewardsTotalAllocation, "ThriveReviewFactory: small reward amount sent");


        // Require reviewersRewardTotalAllocation amount is enough to cover all reviewers potentially
        require(
            reviewConfiguration_.reviewerRewardsTotalAllocation >=
                reviewConfiguration_.reviewerReward * reviewConfiguration_.maximumReviewsPerSubmission * reviewConfiguration_.maximumSubmissions,
            "ThriveReviewFactory: small reward amount"
        );


        // Create a new ThriveReview contract by cloning existing implementation.
        address thriveReviewContract = Clones.clone(thriveReviewContractImplementation);


        // ThriveReview contract should be the ONLY validator on the ThriveWorkUnit contract
        workUnitArgs_.validators = new address[](1);
        workUnitArgs_.validators[0] = thriveReviewContract;


        // Create a new WorkUnit contract that is to be validated by the ThriveReview contract
        address workUnitContract = IThriveWorkerUnitFactory(thriveWorkerUnitFactory).createThriveWorkUnit(workUnitArgs_);


        // Save work unit contract address in review configuration argumentation
        reviewConfiguration_.workUnit = workUnitContract;

        // Initialize the newly created ThriveReview contract.
        IThriveReview(thriveReviewContract).initialize(
            reviewConfiguration_,
            address(this),
            badgeQueryContractAddress,
            _msgSender()
        );


        // Transfer funds allocated as rewards for reviewers immediately to the ThriveReview Contract.
        (bool success, ) = thriveReviewContract.call{value: reviewConfiguration_.reviewerRewardsTotalAllocation}("");
        require(success);



        // ADD EVENTS LATER
        ///////////////////

        return (thriveReviewContract, workUnitContract);
    }

    /**
     * @notice Creates a new ThriveReview contract
     * Optional: This function can be used to connect an existing ThriveWorkUnit to a ThriveReview contract.
     * @param reviewConfiguration_ Struct containing args for the reviewing process.
     */
    function createReviewContract(
        IThriveReview.ReviewConfiguration memory reviewConfiguration_
    ) external payable returns (address) {

        // The amount of THRIVE sent must be equal or greater to the reward amount for reviewers
        require(msg.value >= reviewConfiguration_.reviewerRewardsTotalAllocation, "ThriveReviewFactory: small reward amount sent");


        // Require reviewersRewardTotalAllocation amount is enough to cover potentially all reviewers
        require(
            reviewConfiguration_.reviewerRewardsTotalAllocation >=
                reviewConfiguration_.reviewerReward * reviewConfiguration_.maximumReviewsPerSubmission * reviewConfiguration_.maximumSubmissions,
            "ThriveReviewFactory: small reward amount"
        );


        // Create a new ThriveReview contract by cloning existing implementation.
        address thriveReviewContract = Clones.clone(thriveReviewContractImplementation);


        // Initialize the newly created ThriveReview contract.
        IThriveReview(thriveReviewContract).initialize(
            reviewConfiguration_,
            address(this),
            badgeQueryContractAddress,
            _msgSender()
        );


        // Transfer funds allocated as rewards for reviewers immediately to the ThriveReview Contract.
        (bool success, ) = thriveReviewContract.call{value: reviewConfiguration_.reviewerRewardsTotalAllocation}("");
        require(success);


        // ADD EVENTS LATER ON
        ///////////////////////

        return thriveReviewContract;
    }

    /**
     * @notice Overriden function that enables upgrading the contract.
     * @dev Only the owner of the ThriveReviewFactory contract can upgrade it.
     * @param newImplementation Address of the new implementation contract.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
