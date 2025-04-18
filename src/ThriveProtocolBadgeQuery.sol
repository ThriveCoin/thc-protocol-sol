// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBadgeQuery} from "./IBadgeQuery.sol";
import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import {AccessControlHelper} from "src/libraries/AccessControlHelper.sol";
import {OwnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title BadgeQuery
 * @notice Badge manager using external ThriveProtocolAccessControl and modular access pattern.
 */
contract BadgeQuery is OwnableUpgradeable, IBadgeQuery {
    using AccessControlHelper for IAccessControlEnumerable;

    IAccessControlEnumerable public accessControlEnumerable;
    bytes32 public adminRole;

    mapping(address => mapping(bytes32 => bool)) private _badges;

    event BadgeGranted(address indexed account, bytes32 indexed badgeId);
    event BadgeRevoked(address indexed account, bytes32 indexed badgeId);
    event BadgeUpdated(
        address indexed account, bytes32 indexed badgeId, bool status
    );
    event AccessControlUpdated(
        address indexed accessControl, bytes32 adminRole
    );

    /// @dev Modifier to restrict to badge admins.
    modifier onlyAdmin() {
        accessControlEnumerable.checkRole(adminRole, _msgSender());
        _;
    }

    /**
     * @notice Initializer for upgradeable deployment.
     */
    function initialize(address _accessControlEnumerable, bytes32 _adminRole)
        public
        initializer
    {
        __Ownable_init(_msgSender());

        accessControlEnumerable =
            IAccessControlEnumerable(_accessControlEnumerable);
        adminRole = _adminRole;

        emit AccessControlUpdated(_accessControlEnumerable, _adminRole);
    }

    /**
     * @notice Allows owner to update access control contract and admin role.
     */
    function setAccessControlEnumerable(
        address _accessControlEnumerable,
        bytes32 _role
    ) external onlyOwner {
        accessControlEnumerable =
            IAccessControlEnumerable(_accessControlEnumerable);
        adminRole = _role;

        emit AccessControlUpdated(_accessControlEnumerable, _role);
    }

    /**
     * @notice Grants a badge to a user.
     */
    function grantBadge(address account, bytes32 badgeId) external onlyAdmin {
        _validateBadgeInputs(account, badgeId);
        _badges[account][badgeId] = true;

        emit BadgeGranted(account, badgeId);
    }

    /**
     * @notice Revokes a badge from a user.
     */
    function revokeBadge(address account, bytes32 badgeId) external onlyAdmin {
        _validateBadgeInputs(account, badgeId);
        _badges[account][badgeId] = false;

        emit BadgeRevoked(account, badgeId);
    }

    /**
     * @notice Updates badge status for a user.
     */
    function updateBadge(address account, bytes32 badgeId, bool status)
        external
        onlyAdmin
    {
        _validateBadgeInputs(account, badgeId);
        _badges[account][badgeId] = status;

        emit BadgeUpdated(account, badgeId, status);
    }

    /**
     * @inheritdoc IBadgeQuery
     */
    function hasBadge(address account, bytes32 badgeId)
        external
        view
        override
        returns (bool)
    {
        _validateBadgeInputs(account, badgeId);
        return _badges[account][badgeId];
    }

    function _validateBadgeInputs(address account, bytes32 badgeId)
        internal
        pure
    {
        require(
            account != address(0),
            "ThriveProtocol: address cannot be the zero address."
        );
        require(
            badgeId != "", "ThriveProtocol: badge identifier must not be empty."
        );
    }
}
