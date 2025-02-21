// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import {OwnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlHelper} from "src/libraries/AccessControlHelper.sol";
import {IThriveComplianceStore} from "src/IThriveComplianceStore.sol";

/**
 * @title ThriveComplianceStore
 * @notice Contract for storing and managing compliance checks with access control and upgradability.
 */
contract ThriveComplianceStore is
    OwnableUpgradeable,
    UUPSUpgradeable,
    IThriveComplianceStore
{
    using AccessControlHelper for IAccessControlEnumerable;

    struct ComplianceCheck {
        bool passed; // Indicates if the compliance check was passed
        uint256 updatedAt; // Timestamp of when the compliance check was last updated
    }

    event ComplianceCheckUpdated(
        uint256 indexed checkType,
        address indexed account,
        bool passed,
        uint256 updatedAt,
        address updatedBy
    );

    event CheckTypeValidityDurationUpdated(
        uint256 indexed checkType, uint256 duration, address updatedBy
    );

    IAccessControlEnumerable public accessControlEnumerable;
    bytes32 public role;

    // Mapping from check type to account's compliance status
    mapping(uint256 => mapping(address => ComplianceCheck)) public
        complianceChecks;
    // Mapping from check type to validity duration
    mapping(uint256 => uint256) public checkTypeValidityDurations;

    /**
     * @dev Initializes the contract with an access control contract and a role.
     * @param _accessControlEnumerable The address of the AccessControlEnumerable contract.
     * @param _role The access control role required for administrative actions.
     */
    function initialize(address _accessControlEnumerable, bytes32 _role)
        external
        initializer
    {
        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();
        accessControlEnumerable =
            IAccessControlEnumerable(_accessControlEnumerable);
        role = _role;
    }

    /**
     * @dev Ensures only the contract owner can authorize upgrades.
     * @param newImplementation The address of the new contract implementation.
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    /**
     * @dev Modifier that restricts function execution to users with admin role.
     */
    modifier onlyAdmin() {
        accessControlEnumerable.checkRole(role, msg.sender);
        _;
    }

    /**
     * @dev Sets the access control contract and role.
     * @param _accessControlEnumerable The address of the AccessControlEnumerable contract.
     * @param _role The new access control role.
     */
    function setAccessControlEnumerable(
        address _accessControlEnumerable,
        bytes32 _role
    ) external onlyOwner {
        accessControlEnumerable =
            IAccessControlEnumerable(_accessControlEnumerable);
        role = _role;
    }

    /**
     * @dev Sets the validity duration for a given compliance check type.
     * @param checkType The compliance check type.
     * @param duration The duration (in seconds) for which the check remains valid.
     */
    function setCheckTypeValidityDuration(uint256 checkType, uint256 duration)
        external
        onlyAdmin
    {
        require(duration > 0, "Duration must be greater than 0");
        checkTypeValidityDurations[checkType] = duration;
        emit CheckTypeValidityDurationUpdated(checkType, duration, msg.sender);
    }

    /**
     * @dev Updates the compliance status of an account for a given check type.
     * @param checkType The compliance check type.
     * @param account The address of the account being checked.
     * @param passed Whether the compliance check was passed.
     */
    function setComplianceCheck(uint256 checkType, address account, bool passed)
        external
        onlyAdmin
    {
        require(account != address(0), "Invalid account");
        require(
            checkTypeValidityDurations[checkType] > 0,
            "Validity duration is not set for this check type"
        );
        complianceChecks[checkType][account] =
            ComplianceCheck({passed: passed, updatedAt: block.timestamp});
        emit ComplianceCheckUpdated(
            checkType, account, passed, block.timestamp, msg.sender
        );
    }

    /**
     * @dev Removes the compliance status of an account for a given check type.
     * @param checkType The compliance check type.
     * @param account The address of the account whose compliance check is being removed.
     */
    function removeComplianceCheck(uint256 checkType, address account)
        external
        onlyAdmin
    {
        require(
            complianceChecks[checkType][account].updatedAt > 0,
            "No compliance check exists"
        );
        delete complianceChecks[checkType][account];
        emit ComplianceCheckUpdated(
            checkType, account, false, block.timestamp, msg.sender
        );
    }

    /**
     * @dev Checks whether an account has passed compliance within the validity period.
     * @param checkType The compliance check type.
     * @param account The address of the account to check.
     * @return A boolean indicating whether the compliance check is still valid.
     */
    function passedComplianceCheck(uint256 checkType, address account)
        external
        view
        returns (bool)
    {
        ComplianceCheck memory check = complianceChecks[checkType][account];
        if (check.updatedAt == 0) {
            return false;
        }
        return check.passed
            && (
                block.timestamp - check.updatedAt
                    <= checkTypeValidityDurations[checkType]
            );
    }
}
