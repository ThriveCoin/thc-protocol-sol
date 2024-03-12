// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ThriveCoin admins contract
 * @notice Keeps track of all ThriveCoin admins
 */
contract ThriveCoinAdmins is AccessControl {
    error Not_An_Admin();
    /**
     * @notice hash of ADMIN_ROLE
     */
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Checks if _wallet is an admin
     * @param _wallet address to check
     */
    function isAdmin(address _wallet) external view returns (bool) {
        return hasRole(ADMIN_ROLE, _wallet);
    }

    /**
     * @notice Allows the DEFAULT_ADMIN_ROLE(owner) to grant the ADMIN_ROLE to an account.
     * @param _account The address of the new admin.
     */
    function grantAdminRole(
        address _account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, _account);
    }

    /**
     * @notice Allows the DEFAULT_ADMIN_ROLE(owner) to revoke the ADMIN_ROLE from an account
     * @param _account The address to revoke the role from
     */
    function revokeAdminRole(
        address _account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, _account);
    }
}
