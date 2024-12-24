// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IThriveWorkUnitFactory
 * @dev Interface for the ThriveWorkUnitFactory contract.
 */
interface IThriveWorkUnitFactory {
    /**
     * @notice Creates a new ThriveWorkUnit contract.
     * @param moderator Address of the moderator for the work unit.
     * @param rewardToken Address of the reward token (zero address for native token).
     * @param rewardAmount Reward amount per completion.
     * @param maxRewards Total reward pool for the work unit.
     * @param validationRewardAmount Reward amount for validation.
     * @param deadline Timestamp after which the work unit expires.
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
        uint256 maxCompletionsPerUser;
        address[] validators;
        address assignedContributor;
        address badgeQuery;
    }

    /**
     * @notice Creates a new ThriveWorkUnit contract.
     * @param workUnitArgs Struct containing args for the work unit.
     */
    function createThriveWorkUnit(WorkUnitArgs memory workUnitArgs) external returns (address);
}
