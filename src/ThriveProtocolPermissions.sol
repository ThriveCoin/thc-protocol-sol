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

    constructor() {}

    modifier onlyAdmin(bytes32 _role) {
        require(
            hasRole(_role, msg.sender) == true, "ThriveProtocol: must have role"
        );
        _;
    }

    function createRole(
        bytes32 _chainId,
        string memory _community,
        string memory _role,
        address _account
    ) external onlyAdmin(DEFAULT_ADMIN_ROLE) returns (bytes32) {
        bytes32 role = keccak256(abi.encodePacked(_chainId, _community, _role));
        communityId[role] = CommunityData(_chainId, _community);
        _grantRole(role, _account);

        return role;
    }

    function setRoleAdmin(bytes32 _role)
        external
        onlyAdmin(DEFAULT_ADMIN_ROLE)
    {
        CommunityData memory data = communityId[_role];
        bytes32 adminRole =
            keccak256(abi.encodePacked(data.chainId, data.community, "MANAGER"));
        _setRoleAdmin(_role, adminRole);
    }

    /**
     * @notice Adds community admin address connected with chain ID and community address
     * @param _chainId The ID of the chain
     * @param _communityAddress The address of the community
     * @param _newCommunityAdmin The address of the admin
     */
    function addCommunityAdmin(
        string memory _chainId,
        string memory _communityAddress,
        address _newCommunityAdmin
    ) external onlyAdmin(DEFAULT_ADMIN_ROLE) {
        communityAdmins[_chainId][_communityAddress] = _newCommunityAdmin;
    }

    /**
     * @notice Removes the address of the community admin
     * @param _chainId The ID of the chain
     * @param _communityAddress The address of thr community
     */
    function removeCommunityAdmin(
        string memory _chainId,
        string memory _communityAddress
    ) external onlyAdmin(DEFAULT_ADMIN_ROLE) {
        communityAdmins[_chainId][_communityAddress] = address(0);
    }
}
