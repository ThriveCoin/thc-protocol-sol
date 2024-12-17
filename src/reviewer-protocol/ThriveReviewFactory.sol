// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// @OpenZeppelin imports
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// ThriveProtocol imports
import "./ThriveReview.sol";
import "./ThriveReviewStructs.sol";

/**
 * @title ThriveReviewFactory
 * @dev Factory contract for creating ThriveReview contract instances.
 */
contract ThriveReviewFactory is OwnableUpgradeable, UUPSUpgradeable {

    // EVENTS
    event ReviewContractCreated(address reviewContract);

    // Constructor should NOT be used in UUPS standard
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner) public {        
        __Ownable_init(owner);
        __UUPSUpgradeable_init();
    }

    // should this be restricted ?
    function createReviewContract(ReviewConfiguration memory reviewConfiguration) public returns (address) {

        // send work unit for which the reviewing is being done
        ThriveReview review = new ThriveReview(reviewConfiguration, msg.sender);

        emit ReviewContractCreated(address(review));

        return address(review);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
