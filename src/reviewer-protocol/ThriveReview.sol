// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// @OpenZeppelin imports
import "@openzeppelin/contracts/access/Ownable.sol";

// ThriveProtocol imports
import {ReviewConfiguration} from  "./ThriveReviewStructs.sol";

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

    function commitToReview() public {
        // @dev implement
    }

    // @dev Any user can trigger the deletion of a pending review if the review window has expired without the review being completed.
    function deletePendingReview() external {
        // @dev implement
    }

    function submitReview() public {
        // @dev implement
    }
}
