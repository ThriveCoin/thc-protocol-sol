// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IThriveWorkerUnit
 * @dev Interface for ThriveWorkerUnit contract.
 */
interface IThriveWorkerUnit {
    /**
     * @notice Creates a new ThriveWorkUnit contract.
     * @param moderator Address of the moderator for the work unit.
     * @param rewardToken Address of the reward token (zero address for native token).
     * @param rewardAmount Reward amount per completion.
     * @param maxRewards Total reward pool for the work unit.
     * @param validationRewardAmount Reward amount for validation.
     * @param deadline Timestamp after which the work unit expires.
     * @param validationMetadata Metadata for validation.
     * @param metadataVersion Version of worker unit metadata.
     * @param metadata Worker unit metadata.
     * @param maxCompletionsPerUser Maximum completions allowed per user.
     * @param validators Array of addresses responsible for validation.
     * @param assignedContributor Address of the assigned contributor.
     * @param badgeQuery Address of the badge query contract.
     * @return Address of the newly created ThriveWorkUnit contract.
     */
    struct WorkUnitArgs {
        address moderator;
        address rewardToken;
        uint256 rewardAmount;
        uint256 maxRewards;
        uint256 validationRewardAmount;
        uint256 deadline;
        string validationMetadata;
        string metadataVersion;
        string metadata;
        uint256 maxCompletionsPerUser;
        address[] validators;
        address assignedContributor;
        address badgeQuery;
    }

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
