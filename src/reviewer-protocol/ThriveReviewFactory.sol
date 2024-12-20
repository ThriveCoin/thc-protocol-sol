// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// @OpenZeppelin imports
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

// ThriveProtocol imports
import "./ThriveReview.sol";
import "./interface/IThriveReviewFactory.sol";
import "../interface/IThriveWorkerUnit.sol";
import "../interface/IThriveWorkerUnitFactory.sol";

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

    // Mapping of the number of ThriveReview deployments per address
    mapping(address => uint256) public numberOfThriveReviewDeployments;

    /**
     * EVENTS
     */

    /**
     * @notice Emitted when a new Review contract is created.
     * @param reviewContract Address of the review contract.
     */
    event ReviewContractCreated(address reviewContract);

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
        address thriveReviewContractImplementation_
    ) external initializer {
        // @dev add update function for this address?
        thriveWorkerUnitFactory = thriveWorkerUnitFactory_;

        // Save the implementation address for the ThriveReview contract
        thriveReviewContractImplementation = thriveReviewContractImplementation_;

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
        IThriveWorkerUnitFactory.WorkUnitArgs memory workUnitArgs,
        ReviewConfiguration memory reviewConfiguration
    ) external payable returns (address) {
        // The amount of THRIVE sent must be equal or greater to the reward amount for reviewers
        require(
            msg.value >= reviewConfiguration.reviewerReward,
            "ThriveReviewFactory: incorrect reward amount sent"
        );

        // We can get the "future" address of the ThriveRevire contract by using the Clones library `predictDeterministicAddress` function
        address thriveReviewContractAddress = Clones.predictDeterministicAddress(
                thriveReviewContractImplementation,
                keccak256(
                    abi.encodePacked(
                        address(this),
                        msg.sender,
                        numberOfThriveReviewDeployments[msg.sender]++
                    )
                )
            );

        // Add the ThriveReview contract address to the list of validators on the work unit contract
        workUnitArgs.validators[0] = thriveReviewContractAddress;

        // Create a new WorkUnit contract that is to be validated by the ThriveReview contract
        address workUnitContractAddress = IThriveWorkerUnitFactory(thriveWorkerUnitFactory).createThriveWorkerUnit(workUnitArgs);

        // Create a new ThriveReview contract by cloning existing implementation.
        Clones.cloneDeterministic(thriveReviewContractImplementation,
            keccak256(
                abi.encodePacked(
                    address(this),
                    msg.sender,
                    numberOfThriveReviewDeployments[msg.sender]++
                )
            )
        );
        // Initialize the newly created ThriveReview contract.
        IThriveReview(thriveReviewContractAddress).initialize(
            reviewConfiguration,
            workUnitContractAddress,
            address(this),
            msg.sender
        );

        // Transfer funds allocated as rewards for reviewers immediately to the ThriveReview Contract.
        (bool sucesss, ) = thriveReviewContractAddress.call{value: reviewConfiguration.reviewerReward}("");
        require(sucesss);

        // ADD EVENTS LATER ON

        return thriveReviewContractAddress;
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
        require(msg.value >= reviewConfiguration.reviewerReward,"ThriveReviewFactory: incorrect reward amount sent");

        // Create a new ThriveReview contract by cloning existing implementation.
        address thriveReviewContractAddress = Clones.cloneDeterministic(thriveReviewContractImplementation,
            keccak256(
                abi.encodePacked(
                    address(this),
                    msg.sender,
                    numberOfThriveReviewDeployments[msg.sender]++
                )
            )
        );
        // Initialize the newly created ThriveReview contract.
        IThriveReview(thriveReviewContractAddress).initialize(
            reviewConfiguration,
            workUnitContractAddress,
            address(this),
            msg.sender
        );

        // Transfer funds allocated as rewards for reviewers immediately to the ThriveReview Contract.
        (bool sucesss, ) = thriveReviewContractAddress.call{value: reviewConfiguration.reviewerReward}("");
        require(sucesss);

        // This `if` clause is for the case when the ThriveWorkUnit contract was made beforehand
        // and the moderator wants the new `ThriveReview` contract to be a validator on it.
        if (workUnitContractAddress != address(0)) {

            // Only moderator of the ThriveWorkUnit contract can add a ThriveReview contract as a validator.
            require(
                IThriveWorkerUnit(workUnitContractAddress).isModerator(msg.sender),
                "ThriveReviewFactory: caller is not a moderator"
            );

            // Add the ThriveReview contract address to the list of validators on the work unit contract
            // ...
        }

        // ADD EVENTS LATER ON (CROSS-CHECK WITH INTEGRATIONS)

        return thriveReviewContractAddress;
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
