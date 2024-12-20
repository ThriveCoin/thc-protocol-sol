// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IThriveWorkUnit
 * @dev Interface for ThriveWorkUnit contract.
 */
interface IThriveWorkUnit {
    /**
     * @notice Checks if address is a moderator on the WorkerUnit contract.
     * @param address_ Address to check.
     */
    function isModerator(address address_) external view returns (bool);

    /**
     * @notice Add an address as a validator on the WorkerUnit contract.
     * @param address_ Address to add.
     */
    function addValidator(address address_) external;
}
