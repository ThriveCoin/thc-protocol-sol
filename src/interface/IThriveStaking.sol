// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IThriveWorkerUnit
 * @dev Interface of ThriveStaking contract to be used for ThriveStakedVoting.
 */
interface IThriveStaking {
    function stakers(address user)
        external
        view
        returns (uint256 amount, uint256 stakingTime, uint256 lastRewardTime);
}
