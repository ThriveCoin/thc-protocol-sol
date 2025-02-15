// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IBadgeQuery.sol";

/**
 * @title BadgeQuery
 * @dev Implementation of IBadgeQuery that always returns true.
 * @notice TODO: need to be implemented, this is initial version
 */
contract BadgeQuery is IBadgeQuery {
    /**
     * @notice Always returns true for any address and badgeId.
     * @param _account The address to query (unused).
     * @param _badgeId The ID of the badge to check (unused).
     * @return Always true.
     */
    function hasBadge(address _account, bytes32 _badgeId)
        external
        pure
        override
        returns (bool)
    {
        require(
            _account != address(0),
            "Invalid account: The provided address cannot be the zero address."
        );
        require(
            _badgeId != "",
            "Invalid badge ID: The badge identifier must not be empty."
        );

        return true;
    }
}
