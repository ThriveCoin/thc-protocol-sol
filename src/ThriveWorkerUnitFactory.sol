// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ThriveWorkerUnit.sol";

/**
 * @title ThriveWorkerUnitFactory
 * @dev Factory contract for creating ThriveWorkerUnit instances.
 */
contract ThriveWorkerUnitFactory {
    /**
     * @dev Emitted when a new ThriveWorkerUnit is created.
     * @param unitAddress The address of the newly created work unit contract.
     */
    event ThriveWorkerUnitCreated(address indexed unitAddress);

    /**
     * @notice Creates a new ThriveWorkerUnit contract.
     * @param _moderator Address of the moderator for the work unit.
     * @param _rewardToken Address of the reward token (zero address for native token).
     * @param _rewardAmount Reward amount per completion.
     * @param _maxRewards Total reward pool for the work unit.
     * @param _validationRewardAmount Reward amount for validation.
     * @param _deadline Timestamp after which the work unit expires.
     * @param _maxCompletionsPerUser Maximum completions allowed per user.
     * @param _validators Array of addresses responsible for validation.
     * @param _validationMetadata Validation metadata string.
     * @param _metadata Metadata describing the work unit.
     * @param _badgeQuery Address of the badge query contract.
     * @return Address of the newly created ThriveWorkerUnit contract.
     */
    function createThriveWorkerUnit(
        address _moderator,
        address _rewardToken,
        uint256 _rewardAmount,
        uint256 _maxRewards,
        uint256 _validationRewardAmount,
        uint256 _deadline,
        uint256 _maxCompletionsPerUser,
        address[] memory _validators,
        string memory _validationMetadata,
        string memory _metadata,
        address _badgeQuery
    ) external returns (address) {
        ThriveWorkerUnit unit = new ThriveWorkerUnit(
            _moderator,
            _rewardToken,
            _rewardAmount,
            _maxRewards,
            _validationRewardAmount,
            _deadline,
            _maxCompletionsPerUser,
            _validators,
            _validationMetadata,
            _metadata,
            _badgeQuery
        );

        emit ThriveWorkerUnitCreated(address(unit));

        return address(unit);
    }
}
