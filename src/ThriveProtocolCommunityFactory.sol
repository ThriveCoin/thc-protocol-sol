//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {ThriveProtocolCommunity} from "src/ThriveProtocolCommunity.sol";

contract ThriveProtocolCommunityFactory {
    AccessControlEnumerable public accessControlEnumerable;

    address public rewardsAdmin;
    address public treasuryAdmin;
    address public validationsAdmin;
    address public foundationAdmin;

    uint256 public rewardsPercentage;
    uint256 public treasuryPercentage;
    uint256 public validationsPercentage;
    uint256 public foundationPercentage;

    /**
     * @param _rewardsAdmin The address of the account who has administrator rights for the founds allocated for rewards
     * @param _treasuryAdmin The address of the account who has administrator rights for the founds allocated for DAO treasury
     * @param _validationsAdmin The address of the account who has administrator rights for the founds allocated for validations
     * @param _foundationAdmin The address of the account who has administrator rights for the founds allocated for the foundation
     * @param _rewardsPercentage The value of percentage to add to rewards admin
     * @param _treasuryPercentage The value of percentage to add to treasury admin
     * @param _validationsPercentage The value of percentage to add to validations admin
     * @param _foundationPercentage The value of percentage to add to foundation admin
     * @param _accessControlEnumerable The address of access control enumerable contract
     */
    constructor(
        address _rewardsAdmin,
        address _treasuryAdmin,
        address _validationsAdmin,
        address _foundationAdmin,
        uint256 _rewardsPercentage,
        uint256 _treasuryPercentage,
        uint256 _validationsPercentage,
        uint256 _foundationPercentage,
        address _accessControlEnumerable
    ) {
        accessControlEnumerable = AccessControlEnumerable(
            _accessControlEnumerable
        );

        _setAdmins(
            _rewardsAdmin,
            _treasuryAdmin,
            _validationsAdmin,
            _foundationAdmin
        );
        _setPercentage(
            _rewardsPercentage,
            _treasuryPercentage,
            _validationsPercentage,
            _foundationPercentage
        );
    }

    /**
     * @dev Modifier to only allow execution by admins.
     * If the caller is not an admin, reverts with a corresponding message
     */
    modifier onlyAdmin() {
        require(
            accessControlEnumerable.hasRole(
                accessControlEnumerable.DEFAULT_ADMIN_ROLE(),
                msg.sender
            ),
            "ThriveProtocolCommunity: must have admin role"
        );
        _;
    }

    /**
     * @notice Deploy the community contract
     * can calls only user with DEFAULT_ADMIN role
     * @param _name The name of the community
     * @param _accessControlEnumerable The address of access control enumerable contract
     * @return The address of deployed comminity contract
     */
    function deploy(
        string memory _name,
        address _accessControlEnumerable
    ) external onlyAdmin returns (address) {
        ThriveProtocolCommunity community = new ThriveProtocolCommunity(
            msg.sender,
            _name,
            [rewardsAdmin, treasuryAdmin, validationsAdmin, foundationAdmin],
            [
                rewardsPercentage,
                treasuryPercentage,
                validationsPercentage,
                foundationPercentage
            ],
            _accessControlEnumerable
        );

        return address(community);
    }

    /**
     * @dev Sets the AccessControlEnumerable contract address.
     * Only the owner of this contract can call this function.
     *
     * @param _accessControlEnumerable The address of the new AccessControlEnumerable contract.
     */
    function setAccessControlEnumerable(
        address _accessControlEnumerable
    ) external onlyAdmin {
        accessControlEnumerable = AccessControlEnumerable(
            _accessControlEnumerable
        );
    }

    /**
     * @notice Sets the admins' addresses
     * can call only DEFAULT_ADMIN account
     * @param _rewardsAdmin The address of the account who has administrator rights for the funds allocated for rewards
     * @param _treasuryAdmin The address of the account who has administrator rights for the funds allocated for DAO treasury
     * @param _validationsAdmin The address of the account who has administrator rights for the funds allocated for validations
     * @param _foundationAdmin The address of the account who has administrator rights for the funds allocated for the foundation
     */
    function setAdmins(
        address _rewardsAdmin,
        address _treasuryAdmin,
        address _validationsAdmin,
        address _foundationAdmin
    ) external onlyAdmin {
        _setAdmins(
            _rewardsAdmin,
            _treasuryAdmin,
            _validationsAdmin,
            _foundationAdmin
        );
    }

    /**
     * @notice Sets the percentages for distribution
     * can call only DEFAULT_ADMIN account
     * @param _rewardsPercentage The percentage for the rewards admin
     * @param _treasuryPercentage The percentage for the treasury admin
     * @param _validationsPercentage The percentage for the validations admin
     * @param _foundationPercentage The percentage for the foundation admin
     */
    function setPercentage(
        uint256 _rewardsPercentage,
        uint256 _treasuryPercentage,
        uint256 _validationsPercentage,
        uint256 _foundationPercentage
    ) external onlyAdmin {
        _setPercentage(
            _rewardsPercentage,
            _treasuryPercentage,
            _validationsPercentage,
            _foundationPercentage
        );
    }

    /**
     * @notice Sets the admins' addresses
     * @param _rewardsAdmin The address of the account who has administrator rights for the funds allocated for rewards
     * @param _treasuryAdmin The address of the account who has administrator rights for the funds allocated for DAO treasury
     * @param _validationsAdmin The address of the account who has administrator rights for the funds allocated for validations
     * @param _foundationAdmin The address of the account who has administrator rights for the funds allocated for the foundation
     */
    function _setAdmins(
        address _rewardsAdmin,
        address _treasuryAdmin,
        address _validationsAdmin,
        address _foundationAdmin
    ) internal {
        rewardsAdmin = _rewardsAdmin;
        treasuryAdmin = _treasuryAdmin;
        validationsAdmin = _validationsAdmin;
        foundationAdmin = _foundationAdmin;
    }

    /**
     * @notice Sets the percentages for distribution
     * @param _rewardsPercentage The percentage for the rewards admin
     * @param _treasuryPercentage The percentage for the treasury admin
     * @param _validationsPercentage The percentage for the validations admin
     * @param _foundationPercentage The percentage for the foundation admin
     */
    function _setPercentage(
        uint256 _rewardsPercentage,
        uint256 _treasuryPercentage,
        uint256 _validationsPercentage,
        uint256 _foundationPercentage
    ) internal {
        rewardsPercentage = _rewardsPercentage;
        treasuryPercentage = _treasuryPercentage;
        validationsPercentage = _validationsPercentage;
        foundationPercentage = _foundationPercentage;
    }
}
