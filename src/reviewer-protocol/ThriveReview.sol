// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// @OpenZeppelin imports
import "@openzeppelin/contracts/access/Ownable.sol";

// ThriveProtocol imports
import "./ThriveReviewStructs.sol";

/**
 * @title ThriveReview
 * @dev Contract for managing reviews.
 */
contract ThriveReview is Ownable {

    // STORAGE VARIABLES
    ReviewConfiguration public reviewConfiguration;

    constructor(ReviewConfiguration memory reviewConfiguration_, address owner) Ownable(owner) {
        reviewConfiguration = reviewConfiguration_;
    }
}
