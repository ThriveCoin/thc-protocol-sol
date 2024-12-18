// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// @OpenZeppelin imports
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// ThriveProtocol imports
import "./ThriveReview.sol";
import "./interface/IThriveReviewFactory.sol";
import "../interface/IThriveWorkerUnitFactory.sol";

/**
 * @title ThriveReviewFactory
 * @dev Factory contract for creating ThriveReview contract instances.
 */
contract ThriveReviewFactory is OwnableUpgradeable, UUPSUpgradeable, IThriveReviewFactory {


    /**
     * STORAGE VARIABLES
     */

    // Mapping of review contract address to work unit address
    mapping(address => address) public reviewToWorkUnit;

    // Mapping of work unit address to review contract address
    mapping(address => address) public workUnitToReview;

    // Address of the ThriveWorkerUnitFactory contract
    address public thriveWorkerUnitFactory;



    // EVENTS ////////
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
    function initialize(address owner_, address thriveWorkerUnitFactory_) external initializer {

        // @dev add update function for this address
        thriveWorkerUnitFactory = thriveWorkerUnitFactory_;

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
    ) external payable onlyOwner returns (address) {

        // @dev connecting to existing infrastructure/contracts to create work units
        address workUnitContractAddress = IThriveWorkerUnitFactory(thriveWorkerUnitFactory).createThriveWorkerUnit(workUnitArgs);

        // Create a new review contract
        ThriveReview review = new ThriveReview(reviewConfiguration, workUnitContractAddress, msg.sender);

        // Map the review contract to the work unit
        reviewToWorkUnit[address(review)] = workUnitContractAddress;

        // Map the work unit to the review contract
        workUnitToReview[workUnitContractAddress] = address(review);

        uint256 ThriveAmountToDistributeToReviewers = msg.value;

        (bool sucesss,) = address(review).call{value: ThriveAmountToDistributeToReviewers}("");
        require(sucesss);

        emit ReviewContractCreated(address(review));

        return address(review);
    }


    /**
     * @notice Overriden function that enables upgrading the contract.
     * @param newImplementation Address of the new implementation contract.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
