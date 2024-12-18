// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// @OpenZeppelin imports
import "@openzeppelin/contracts/access/Ownable.sol";

// ThriveProtocol imports
import "./interface/IThriveReviewFactory.sol";
import "./interface/IThriveReview.sol";

/**
 * @title ThriveReview
 * @dev Contract for managing reviews.
 */
contract ThriveReview is Ownable, IThriveReviewFactory, IThriveReview {

    /**
     * Storage variables
     */

    // Review configuration - rules to follow when conducting a "review"
    IThriveReviewFactory.ReviewConfiguration public reviewConfiguration;

    // Address of the work unit contract
    address public workUnitContractAddress;

    constructor(ReviewConfiguration memory reviewConfiguration_, address workUnitContractAddress_, address owner_) Ownable(owner_) {
        workUnitContractAddress = workUnitContractAddress_;
        reviewConfiguration = reviewConfiguration_;
    }
}
