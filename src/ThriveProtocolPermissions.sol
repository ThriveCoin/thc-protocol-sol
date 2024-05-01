//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";

contract ThriveProtocolPermissions {
    ThriveProtocolAccessControl public accessControl;
    address public rootAdmin;

    mapping(string chainId => mapping(string communityAddress => address admin))
        public communityAdmins;

    /**
     *
     * @param _rootAdmin The address of the base admin
     */
    constructor(address _rootAdmin, address _accessControl) {
        rootAdmin = _rootAdmin;
        accessControl = ThriveProtocolAccessControl(_accessControl);
    }

    modifier onlyAdmin(bytes32 _role) {
        require(
            accessControl.hasRole(_role, msg.sender) == true,
            "ThriveProtocol: must have role"
        );
        _;
    }

    modifier onlyManager(bytes32 _chainId, string memory _community) {
        bytes32 role =
            keccak256(abi.encodePacked(_chainId, _community, "MANAGER"));
        require(
            accessControl.hasRole(role, msg.sender),
            "ThriveProtocol: must have MANAGER role"
        );
        _;
    }

    function createRole(
        bytes32 _chainId,
        string memory _community,
        string memory _role,
        bytes32 _adminRole
    )
        external
        onlyAdmin(accessControl.DEFAULT_ADMIN_ROLE())
        returns (bytes32)
    {
        bytes32 role = keccak256(abi.encodePacked(_chainId, _community, _role));
        accessControl.setRoleAdmin(role, _adminRole);

        return role;
    }

    function grantRole(
        bytes32 _chainId,
        string memory _community,
        string memory _role,
        address _account
    ) external onlyManager(_chainId, _community) {
        bytes32 role = keccak256(abi.encodePacked(_chainId, _community, _role));
        accessControl.setRole(role, _account);
    }

    /**
     * @notice Check the address is the admin of the community
     * @param _chainId The ID of the chain
     * @param _communityAddress The address of the community
     * @param _communityAdmin The address of the admin
     */
    function checkAdmin(
        string memory _chainId,
        string memory _communityAddress,
        address _communityAdmin
    ) external view returns (bool) {
        require(
            communityAdmins[_chainId][_communityAddress] == _communityAdmin,
            "ThriveProtocol: not an community admin"
        );

        return true;
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
    ) external {
        require(msg.sender == rootAdmin, "ThriveProtocol: not a root admin");
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
    ) external {
        require(msg.sender == rootAdmin, "ThriveProtocol: not a root admin");
        communityAdmins[_chainId][_communityAddress] = address(0);
    }
}
