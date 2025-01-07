// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IThriveWorkerUnit
 * @dev Interface for ThriveWorkerUnit contract.
 */
interface IThriveWorkerUnit {

    /**
     * @notice Initializes the ThriveWorkerUnit contract.
     */
    function initialize() external payable;

    /**
     * @notice Checks if address is a moderator on the WorkerUnit contract.
     * @param address_ Address to check.
     */
    function isModerator(address address_) external view returns (bool);

    /**
     * @notice Add an address as a validator on the WorkerUnit contract.
     * @param address_ Address to add.
     */
    function addReviewContractAsValidator(address address_) external;

    /**
     * @notice Fetches all validators from ThriveWorkUnit contract.
     * @return Array of validator addresses.
     */
    function getValidators() external view returns (address[] memory);

    /**
     * @notice Confirms a submission from ThriveReview contract is eligible for payout on ThriveWorkerUnit.
     */
    function confirm(address, string memory) external;

    /**
     * @notice Add a required badge to ThriveWorkerUnit contract.
     */
    function addRequiredBadge(bytes32 badge) external;

    /**
     * @notice Set the review factory address on ThriveWorkerUnit contract.
     */
    function setThriveReviewFactoryAddress(address) external;

    // Max rewards on WorkerUnit
    function maxRewards() external view returns (uint256);

    // Reward amount on WorkerUnit
    function rewardAmount() external view returns (uint256);

}
