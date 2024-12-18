// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ThriveWorkerUnit.sol";
import "./interface/IThriveWorkerUnitFactory.sol";

/**
 * @title ThriveWorkerUnitFactory
 * @dev Factory contract for creating ThriveWorkerUnit instances.
 */
contract ThriveWorkerUnitFactory is IThriveWorkerUnitFactory {


    /**
     * @dev Emitted when a new ThriveWorkerUnit is created.
     * @param unitAddress The address of the newly created work unit contract.
     */
    event ThriveWorkerUnitCreated(address indexed unitAddress);

    /**
     * @notice Creates a new ThriveWorkerUnit contract.
     * @dev Inherits documentation for arguments from IThriveWorkerUnitFactory.
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
        address _assignedContributor,
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
            _assignedContributor,
            _badgeQuery
        );

        emit ThriveWorkerUnitCreated(address(unit));

        return address(unit);
    }


    /**
     * @notice Creates a new ThriveWorkerUnit contract.
     * @dev Inherits documentation from IThriveWorkerUnitFactory.
     * @inheritdoc IThriveWorkerUnitFactory
     * @param workUnitArgs The arguments required to create a ThriveWorkerUnit.
     * @return address The address of the newly created ThriveWorkerUnit.
     */
    function createThriveWorkerUnit(
        WorkUnitArgs memory workUnitArgs // @dev Maybe add a restrict method to this call
    ) external returns (address) {
        ThriveWorkerUnit unit = new ThriveWorkerUnit(
            workUnitArgs.moderator,
            workUnitArgs.rewardToken,
            workUnitArgs.rewardAmount,
            workUnitArgs.maxRewards,
            workUnitArgs.validationRewardAmount,
            workUnitArgs.deadline,
            workUnitArgs.maxCompletionsPerUser,
            workUnitArgs.validators,
            workUnitArgs.assignedContributor,
            workUnitArgs.badgeQuery
        );

        emit ThriveWorkerUnitCreated(address(unit));

        return address(unit);
    }
}
