// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControlEnumerableUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {UUPSUpgradeable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title ThriveProtocolAccessControl
 * @notice This contract manages access control using roles and provides upgradeability.
 */
contract ThriveProtocolAccessControl is
    AccessControlEnumerableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    /**
     * @notice Initializes the contract, setting up roles and ownership.
     */
    function initialize() public initializer {
        __AccessControlEnumerable_init();
        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @notice Authorizes the upgrade of the contract.
     * @param newImplementation The address of the new implementation.
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    /**
     * @notice Sets the admin role for a given role.
     * @param role The role to change the admin for.
     * @param adminRole The new admin role.
     */
    function setRoleAdmin(bytes32 role, bytes32 adminRole)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setRoleAdmin(role, adminRole);
    }
}
