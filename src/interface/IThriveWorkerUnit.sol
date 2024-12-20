// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IThriveWorkerUnit
 * @dev Interface for ThriveWorkerUnit contract.
 */
interface IThriveWorkerUnit {
    /**
     * @notice Checks if address is a moderator on the WorkerUnit contract.
     */
    function isModerator(address address_) external view returns (bool);
}
