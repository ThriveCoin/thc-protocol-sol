//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";

contract ThriveProtocolPermissions is ThriveProtocolAccessControl {

    function createRole(
        bytes32 _chainId,
        string memory _community,
        string memory _role,
        address _account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bytes32) {
        bytes32 role = keccak256(abi.encodePacked(_chainId, _community, _role));
        _grantRole(role, _account);

        return role;
    }

    function setRoleAdmin(bytes32 _role, bytes32 _adminRole)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setRoleAdmin(_role, _adminRole);
    }
}
