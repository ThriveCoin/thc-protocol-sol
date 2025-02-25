// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IThriveComplianceStore {
    /**
     * @dev Checks whether an account has passed compliance within the validity period.
     * @param checkType The compliance check type.
     * @param account The address of the account to check.
     * @return A boolean indicating whether the compliance check is still valid.
     */
    function passedComplianceCheck(bytes32 checkType, address account)
        external
        view
        returns (bool);
}
