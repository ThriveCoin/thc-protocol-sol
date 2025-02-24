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
     * @notice Creates a new ThriveWorkerUnit contract using a WorkUnitArgs struct.
     * @dev This function is payable to forward ETH to the worker unit’s initialize function.
     * @return Address of the newly created ThriveWorkerUnit contract.
     */
    function createThriveWorkUnit(WorkUnitArgs memory workUnitArgs)
        external
        payable
        returns (address)
    {
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

        if (workUnitArgs.rewardToken != address(0)) {
            IERC20(workUnitArgs.rewardToken).approve(
                address(unit), workUnitArgs.maxRewards
            );
        }
        unit.initialize{value: msg.value}();

        return address(unit);
    }
}
