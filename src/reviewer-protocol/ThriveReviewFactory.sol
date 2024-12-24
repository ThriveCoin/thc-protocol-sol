// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// @OpenZeppelin imports
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

// ThriveProtocol imports
import "./ThriveReview.sol";
import "./interface/IThriveReviewFactory.sol";
import "../interface/IThriveWorkUnit.sol";
import "../interface/IThriveWorkUnitFactory.sol";

/**
 * @title ThriveReviewFactory
 * @dev Factory contract for creating ThriveReview contract instances.
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
     * what needs to work
     * 
     * big areas to still cover:
     * money flow for submitters and reviewers - when do they get paid?
     * double linked list
     * restrictions (max submits, thresholds, bla bla), timestamp deadlines for everything
     * 
     * - tests, tests, tests
     */


    // Implementation contract should be disabled per UUPS standard
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract.
     * @param owner_ Address of the owner of the contract.
     * @param thriveWorkerUnitFactory_ Address of the ThriveWorkerUnitFactory contract.
     */
    function initialize(
        address owner_,
        address thriveWorkerUnitFactory_,
        address thriveReviewContractImplementation_,
        address badgeQueryContractAddress_
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
    }

    /**
     * @notice Creates new WorkerUnit and ThriveReview contracts.
     * @param workUnitArgs Struct containing args for properly initializing WorkUnit contract.
     * @param reviewConfiguration Struct containing args for the review.
     * @return Address of the newly created ThriveReview contract.
     */
    function createWorkUnitAndReviewContract(
        IThriveWorkUnitFactory.WorkUnitArgs memory workUnitArgs,
        ReviewConfiguration memory reviewConfiguration
    ) external payable returns (address) {

        // The amount of THRIVE sent must be equal or greater to the reward amount for reviewers
        require(
            msg.value >= reviewConfiguration.totalReviewerReward,
            "ThriveReviewFactory: incorrect reward amount sent"
        );

        // Create a new ThriveReview contract by cloning existing implementation.
        address thriveReviewContract = Clones.clone(thriveReviewContractImplementation);

        // Add the ThriveReview contract address to the list of validators on the work unit contract
        uint256 workUnitValidatorsLength = workUnitArgs.validators.length;
        workUnitArgs.validators[workUnitValidatorsLength] = thriveReviewContract;

        // Create a new WorkUnit contract that is to be validated by the ThriveReview contract
        address workUnitContractAddress = IThriveWorkUnitFactory(thriveWorkerUnitFactory).createThriveWorkUnit(workUnitArgs);

        // Initialize the newly created ThriveReview contract.
        IThriveReview(thriveReviewContract).initialize(
            reviewConfiguration,
            workUnitContractAddress,
            address(this),
            badgeQueryContractAddress,
            msg.sender
        );

        // Transfer funds allocated as rewards for reviewers immediately to the ThriveReview Contract.
        (bool sucesss, ) = thriveReviewContract.call{value: reviewConfiguration.totalReviewerReward}("");
        require(sucesss);

        // ADD EVENTS LATER ON

        return thriveReviewContract;
    }

    /**
     *
     * @param reviewConfiguration TODO.
     * @param workUnitContractAddress Address of the work unit contract.
     */
    function createReviewContract(
        ReviewConfiguration memory reviewConfiguration,
        address workUnitContractAddress
    ) external payable returns (address) {

        // The amount of THRIVE sent must be equal or greater to the reward amount for reviewers
        require(msg.value >= reviewConfiguration.totalReviewerReward,"ThriveReviewFactory: incorrect reward amount sent");

        // Create a new ThriveReview contract by cloning existing implementation.
        address thriveReviewContract = Clones.clone(thriveReviewContractImplementation);

        // Initialize the newly created ThriveReview contract.
        IThriveReview(thriveReviewContract).initialize(
            reviewConfiguration,
            workUnitContractAddress,
            address(this),
            badgeQueryContractAddress,
            msg.sender
        );

        // Transfer funds allocated as rewards for reviewers immediately to the ThriveReview Contract.
        (bool sucesss, ) = thriveReviewContract.call{value: reviewConfiguration.totalReviewerReward}("");
        require(sucesss);

        // This `if` clause is for the case when the ThriveWorkUnit contract was made beforehand
        // and the moderator wants the new `ThriveReview` contract to be a validator on it.
        if (workUnitContractAddress != address(0)) {

            // Only moderator of the ThriveWorkUnit contract can add a ThriveReview contract as a validator.
            require(
                IThriveWorkUnit(workUnitContractAddress).isModerator(msg.sender), // @dev can we do this, is the moderator address an EOA?
                "ThriveReviewFactory: caller is not a moderator"
            );

            // Add the ThriveReview contract address to the list of validators on the work unit contract - should this only be allowed to be done once? 
            IThriveWorkUnit(workUnitContractAddress).addValidator(thriveReviewContract);
        }

        // ADD EVENTS LATER ON (CROSS-CHECK WITH INTEGRATIONS - frontend, backend)

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
