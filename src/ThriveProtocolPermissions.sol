//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import {AccessControlHelper} from "src/libraries/AccessControlHelper.sol";

contract ThriveProtocolPermissions {
    using AccessControlHelper for IAccessControlEnumerable;

    IAccessControlEnumerable public accessControlEnumerable;
    bytes32 public adminRole;

    address public rootAdmin;

    mapping(string chainId => mapping(string communityAddress => address admin))
        public communityAdmins;

    /**
     *
     * @param _accessControlEnumerable The address of access control contract
     * @param _role The role for access control
     */
    constructor(address _accessControlEnumerable, bytes32 _role, address _rootAdmin) {
        accessControlEnumerable =
            IAccessControlEnumerable(_accessControlEnumerable);
        adminRole = _role;
        rootAdmin = _rootAdmin;
    }

    /**
     * @dev Modifier to allow only admins to execute a function.
     * Reverts if the caller is not an admin with a corresponding message.
     */
    modifier onlyAdmin() {
        accessControlEnumerable.checkRole(adminRole, msg.sender);
        _;
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
    ) external onlyAdmin {
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
    ) external onlyAdmin {
        communityAdmins[_chainId][_communityAddress] = address(0);
    }

     /**
     * @dev Sets the AccessControlEnumerable contract address.
     * Only the owner of this contract can call this function.
     *
     * @param _accessControlEnumerable The new address of the AccessControlEnumerable contract.
     * @param _adminRole The new admin role to use for access control.
     */
    function setAccessControlEnumerable(
        address _accessControlEnumerable,
        bytes32 _adminRole
    ) external onlyAdmin {
        accessControlEnumerable =
            IAccessControlEnumerable(_accessControlEnumerable);
        adminRole = _adminRole;
    }
}
