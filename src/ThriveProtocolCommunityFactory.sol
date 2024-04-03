//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {ThriveProtocolCommunity} from "src/ThriveProtocolCommunity.sol";

contract ThriveProtocolCommunityFactory {
    AccessControlEnumerable public accessControlEnumerable;

    address private rewardsAdmin;
    address private treasuryAdmin;
    address private validationsAdmin;
    address private foundationAdmin;

    uint256 private rewardsPercentage;
    uint256 private treasuryPercentage;
    uint256 private validationsPercentage;
    uint256 private foundationPercentage;

    /**
     * @param _rewardsAdmin The address of the account who has administrator rights for the funds allocated for rewards
     * @param _treasuryAdmin The address of the account who has administrator rights for the funds allocated for DAO treasury
     * @param _validationsAdmin The address of the account who has administrator rights for the funds allocated for validations
     * @param _foundationAdmin The address of the account who has administrator rights for the funds allocated for the foundation
     * @param _rewardsPercentage The value of percentage to add to rewards admin
     * @param _treasuryPercentage The value of percentage to add to treasury admin
     * @param _validationsPercentage The value of percentage to add to validations admin
     * @param _foundationPercentage The value of percentage to add to foundation admin
     */
    constructor(
        address _rewardsAdmin,
        address _treasuryAdmin,
        address _validationsAdmin,
        address _foundationAdmin,
        uint256 _rewardsPercentage,
        uint256 _treasuryPercentage,
        uint256 _validationsPercentage,
        uint256 _foundationPercentage
    ) {
        _setAdmins(
            _rewardsAdmin,
            _treasuryAdmin,
            _validationsAdmin,
            _foundationAdmin
        );
        _setPercentages(
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
    function setPercentages(
        uint256 _rewardsPercentage,
        uint256 _treasuryPercentage,
        uint256 _validationsPercentage,
        uint256 _foundationPercentage
    ) external onlyAdmin {
        _setPercentages(
            _rewardsPercentage,
            _treasuryPercentage,
            _validationsPercentage,
            _foundationPercentage
        );
    }

    /**
     * @notice Returns the address of the account who has administrator rights for the funds allocated for rewards
     * @return The address of rewards admin
     */
    function getRewardsAdmin() public view returns (address) {
        return rewardsAdmin;
    }

    /**
     * @notice Returns the address of the account who has administrator rights for the funds allocated for DAO treasury
     * @return The address of treasuty admin
     */
    function getTreasuryAdmin() public view returns (address) {
        return treasuryAdmin;
    }

    /**
     * @notice Returns the address of the account who has administrator rights for the funds allocated for validations
     * @return The address of validations admin
     */
    function getValidationsAdmin() public view returns (address) {
        return validationsAdmin;
    }

    /**
     * @notice Returns the address of the account who has administrator rights for the funds allocated for the foundation
     * @return The address of foundation admin
     */
    function getFoundationAdmin() public view returns (address) {
        return foundationAdmin;
    }

    /**
     * @notice Returns the percentage for the rewards
     * @return The value of rewards percentage
     */
    function getRewardsPercentage() public view returns (uint256) {
        return rewardsPercentage;
    }

    /**
     * @notice Returns the percentage for the treasury
     * @return The value of treasuty percentage
     */
    function getTreasuryPercentage() public view returns (uint256) {
        return treasuryPercentage;
    }

    /**
     * @notice Returns the percentage for the validations
     * @return The value of validations percentage
     */
    function getValidationsPercentage() public view returns (uint256) {
        return validationsPercentage;
    }

    /**
     * @notice Returns the percentage for the the foundation
     * @return The address of foundation admin
     */
    function getFoundationPercentage() public view returns (uint256) {
        return foundationPercentage;
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
    function _setPercentages(
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
