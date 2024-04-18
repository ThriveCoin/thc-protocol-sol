//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import {AccessControlHelper} from "src/libraries/AccessControlHelper.sol";

contract ThriveProtocolContributors {
    using AccessControlHelper for IAccessControlEnumerable;

    IAccessControlEnumerable public accessControlEnumerable;
    bytes32 public adminRole;

    /**
     * @dev Must trigger when a validated contribution is added
     * @param id The id of validated contribution
     * @param contributionId The id of contribution
     * @param metadataIdentifier The metadata identifier for contribution
     * @param endEntityAddress The end entity that received reward of token
     * @param addressChain The address of chain
     * @param token The address of token
     * @param reward The value of reward
     * @param validators Validators and their respective rewards
     */
    event ValidatedContributionAdded(
        uint indexed id,
        uint indexed contributionId,
        string metadataIdentifier,
        string endEntityAddress,
        string addressChain,
        string token,
        uint reward,
        ValidatorReward[] validators
    );

    /**
     * @dev The data structure used to represent validators and their respective rewards
     */
    struct ValidatorReward {
        address validator;
        uint256 reward;
    }

    /**
     * @dev The data structure used information about validated contributions in the Thrive Protocol. It will contain information
     * about which address completed which contribution and what was the reward amount associated with it
     */
    struct ValidatedContribution {
        uint contributionId;
        string metadataIdentifier;
        string endEntityAddress;
        string addressChain;
        string token;
        uint reward;
        uint validatorsCount;
        mapping(uint => ValidatorReward) validators;
    }

    uint256 internal _validatedContributionCount;

    mapping(uint256 id => ValidatedContribution contribution) internal
        contributions;

    /**
     *
     * @param _accessControlEnumerable The address of access control contract
     * @param _role The role for access control
     */
    constructor(address _accessControlEnumerable, bytes32 _role) {
        accessControlEnumerable =
            IAccessControlEnumerable(_accessControlEnumerable);
        adminRole = _role;
    }

    /**
     * @dev Modifier to only allow execution by admins.
     * If the caller is not an admin, reverts with a corresponding message
     */
    modifier onlyAdmin() {
        accessControlEnumerable.checkRole(adminRole, msg.sender);
        _;
    }

    /**
     * @notice Returns the number of contributions validated
     * @return The number of contributions validated
     */
    function validatedContributionCount() public view returns (uint256) {
        return _validatedContributionCount;
    }

    /**
     * @notice Adds a new validated contribution
     * @param _contributionId The id of contribution
     * @param _metadataIdentifier The metadata identifier for contribution
     * @param _endEntityAddress The end entity that received reward of token
     * @param _addressChain The address of chain
     * @param _token The address of token
     * @param _reward The value of reward
     * @param _validatorsRewards Validators and their respective rewards
     */
    function addValidatedContribution(
        uint _contributionId,
        string memory _metadataIdentifier,
        string memory _endEntityAddress,
        string memory _addressChain,
        string memory _token,
        uint _reward,
        ValidatorReward[] memory _validatorsRewards
    ) public onlyAdmin returns (bool success) {
        ValidatedContribution storage contribution =
            contributions[_contributionId];
        contribution.contributionId = _contributionId;
        contribution.metadataIdentifier = _metadataIdentifier;
        contribution.endEntityAddress = _endEntityAddress;
        contribution.addressChain = _addressChain;
        contribution.token = _token;
        contribution.reward = _reward;

        for (uint256 i = 0; i < _validatorsRewards.length; i++) {
            ValidatorReward memory reward = _validatorsRewards[i];
            contribution.validators[i] = reward;
            contribution.validatorsCount++;
        }

        _validatedContributionCount++;

        emit ValidatedContributionAdded(
            _validatedContributionCount,
            contribution.contributionId,
            contribution.metadataIdentifier,
            contribution.endEntityAddress,
            contribution.addressChain,
            contribution.token,
            contribution.reward,
            _validatorsRewards
        );

        return true;
    }

    /**
     * @notice Returns information of a specific validated contribution
     * @param _id The id of contribution
     * @return The id of validated contribution
     * @return The metadata identifier for contribution
     * @return The end entity that received reward of token
     * @return The address of chain
     * @return The address of token
     * @return The value of reward
     * @return Validators and their respective rewards
     */
    function getValidatedContribution(uint _id)
        public
        view
        returns (
            uint,
            string memory,
            string memory,
            string memory,
            string memory,
            uint,
            ValidatorReward[] memory
        )
    {
        ValidatorReward[] memory validators =
            new ValidatorReward[](contributions[_id].validatorsCount);
        for (uint256 i = 0; i < validators.length; i++) {
            validators[i] = contributions[_id].validators[i];
        }

        return (
            contributions[_id].contributionId,
            contributions[_id].metadataIdentifier,
            contributions[_id].endEntityAddress,
            contributions[_id].addressChain,
            contributions[_id].token,
            contributions[_id].reward,
            validators
        );
    }

    /**
     * @dev Sets the AccessControlEnumerable contract address.
     * Only the owner of this contract can call this function.
     *
     * @param _accessControlEnumerable The address of the new AccessControlEnumerable contract.
     * @param _adminRole The role for access control
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
