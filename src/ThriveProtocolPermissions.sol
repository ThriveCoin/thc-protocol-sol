//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";

contract ThriveProtocolPermissions is ThriveProtocolAccessControl {
    mapping(string chainId => mapping(string communityAddress => address admin))
        public communityAdmins;

    struct CommunityData {
        bytes32 chainId;
        string community;
    }

    mapping(bytes32 role => CommunityData) communityId;

    function createRole(
        bytes32 _chainId,
        string memory _community,
        string memory _role,
        address _account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bytes32) {
        bytes32 role = keccak256(abi.encodePacked(_chainId, _community, _role));
        communityId[role] = CommunityData(_chainId, _community);
        _grantRole(role, _account);

        return role;
    }

    function setRoleAdmin(bytes32 _role, string memory _adminRoleName)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        CommunityData memory data = communityId[_role];
        bytes32 adminRole = keccak256(
            abi.encodePacked(data.chainId, data.community, _adminRoleName)
        );
        _setRoleAdmin(_role, adminRole);
    }
}
