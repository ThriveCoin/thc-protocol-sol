// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IBadgeQuery
 * @dev Interface for querying badge ownership.
 */
interface IBadgeQuery {
    /**
     * @notice Checks if an address holds a specific badge.
     * @param account The address to query.
     * @param badgeId The ID of the badge to check.
     * @return hasBadge A boolean indicating whether the address holds the badge.
     */
    function hasBadge(address account, bytes32 badgeId) external view returns (bool hasBadge);
}
