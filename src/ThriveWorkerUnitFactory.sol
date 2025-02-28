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
     * @dev This function is payable to forward ETH to the worker unit's initialize function.
     * @return Address of the newly created ThriveWorkerUnit contract.
     */
    function createThriveWorkUnit(WorkUnitArgs memory workUnitArgs)
        external
        payable
        returns (address)
    {
        ThriveWorkerUnit.WorkerUnitArgs memory convertedArgs = ThriveWorkerUnit
            .WorkerUnitArgs({
            moderator: workUnitArgs.moderator,
            rewardToken: workUnitArgs.rewardToken,
            rewardAmount: workUnitArgs.rewardAmount,
            maxRewards: workUnitArgs.maxRewards,
            validationRewardAmount: workUnitArgs.validationRewardAmount,
            deadline: workUnitArgs.deadline,
            validationMetadata: workUnitArgs.validationMetadata,
            metadataVersion: workUnitArgs.metadataVersion,
            metadata: workUnitArgs.metadata,
            maxCompletionsPerUser: workUnitArgs.maxCompletionsPerUser,
            validators: workUnitArgs.validators,
            assignedContributor: workUnitArgs.assignedContributor,
            badgeQuery: workUnitArgs.badgeQuery
        });

        ThriveWorkerUnit unit = new ThriveWorkerUnit(convertedArgs);

        emit ThriveWorkerUnitCreated(address(unit));

        if (workUnitArgs.rewardToken != address(0)) {
            IERC20(workUnitArgs.rewardToken).approve(
                address(unit), workUnitArgs.maxRewards
            );
        }
        unit.initialize{value: msg.value}();

        return address(unit);
    }

    function getRequiredNativeFunds(
        uint256 _rewardAmount,
        uint256 _maxRewards,
        uint256 _validationRewardAmount,
        address _rewardToken
    ) external pure returns (uint256) {
        uint256 maxRewardsCounter = _maxRewards / _rewardAmount;
        uint256 totalValidatorCost = maxRewardsCounter * _validationRewardAmount;
        return _rewardToken == address(0)
            ? totalValidatorCost + _maxRewards
            : totalValidatorCost;
    }
}
