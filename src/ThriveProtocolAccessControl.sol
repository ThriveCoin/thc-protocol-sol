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
 * @notice Contract that is used to manage access control.
 */
contract ThriveProtocolAccessControl is
    AccessControlEnumerableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    function initialize() public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function setRoleAdmin(bytes32 _role, bytes32 _adminRole)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setRoleAdmin(_role, _adminRole);
    }
}
