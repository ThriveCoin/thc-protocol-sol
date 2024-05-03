//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import {AccessControlHelper} from "src/libraries/AccessControlHelper.sol";
import {ThriveProtocolContributions} from "src/ThriveProtocolContributions.sol";

contract ThriveProtocolContributors is ThriveProtocolContributions {
    using AccessControlHelper for IAccessControlEnumerable;

    IAccessControlEnumerable public accessControlEnumerable;
    bytes32 public adminRole;

    /**
     * @dev Must trigger when a validated contribution is added
     * @param id The ID of the validated contribution
     * @param contributionId The ID of contribution
     * @param metadataURI The metadata identifier for the contribution
     * @param endEntityAddress The address of the entity that received the token reward
     * @param addressChain The address of the chain
     * @param token The address of the token
     * @param reward The value of the reward
     * @param validators Validators and their respective rewards
     */
    event ValidatedContributionAdded(
        uint indexed id,
        uint indexed contributionId,
        string metadataURI,
        string endEntityAddress,
        string addressChain,
        string token,
        uint reward,
        ValidatorReward[] validators
    );

    /**
     * @dev Represents validators and their respective rewards
     */
    struct ValidatorReward {
        address validator;
        uint256 reward;
    }

    /**
     * @dev Represents a validated contribution in the Thrive Protocol. It contains information
     * about which address completed which contribution and the associated reward amount.
     */
    struct ValidatedContribution {
        uint contributionId;
        string metadataURI;
        string endEntityAddress;
        string addressChain;
        string token;
        uint reward;
        uint validatorsCount;
        mapping(uint => ValidatorReward) validators;
    }

    uint256 internal _validatedContributionCount;

    mapping(uint256 id => ValidatedContribution contribution) internal
        validatedContributions;

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
     * @dev Modifier to allow only admins to execute a function.
     * Reverts if the caller is not an admin with a corresponding message.
     */
    modifier onlyAdmin() {
        accessControlEnumerable.checkRole(adminRole, msg.sender);
        _;
    }

    modifier onlyContributionValidator(uint256 _contributionId) {
        require(
            contributions[_contributionId].validator == msg.sender,
            "ThriveProtocol: not a validator of contribution"
        );
        _;
    }

    /**
     * @notice Returns the number of validated contributions
     * @return The number of validated contributions
     */
    function validatedContributionCount() public view returns (uint256) {
        return _validatedContributionCount;
    }

    /**
     * @notice Adds a new validated contribution
     * @param _contributionId The ID of the contribution
     * @param _metadataURI The metadata identifier for the contribution
     * @param _endEntityAddress The address of the entity that received the token reward
     * @param _addressChain The address of the chain
     * @param _token The address of the token
     * @param _reward The value of the reward
     * @param _validatorsRewards Array of validators and their respective rewards
     */
    function addValidatedContribution(
        uint _contributionId,
        string memory _metadataURI,
        string memory _endEntityAddress,
        string memory _addressChain,
        string memory _token,
        uint _reward,
        ValidatorReward[] memory _validatorsRewards
    )
        public
        onlyContributionValidator(_contributionId)
        returns (bool success)
    {
        ValidatedContribution storage contribution =
            validatedContributions[_contributionId];
        contribution.contributionId = _contributionId;
        contribution.metadataURI = _metadataURI;
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
            contribution.metadataURI,
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
     * @param _id The ID of the contribution
     * @return The ID of the validated contribution
     * @return The metadata identifier for the contribution
     * @return The end entity that received reward of token
     * @return The address of the chain
     * @return The address of the token
     * @return The value of the reward
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
            new ValidatorReward[](validatedContributions[_id].validatorsCount);
        for (uint256 i = 0; i < validators.length; i++) {
            validators[i] = validatedContributions[_id].validators[i];
        }

        return (
            validatedContributions[_id].contributionId,
            validatedContributions[_id].metadataURI,
            validatedContributions[_id].endEntityAddress,
            validatedContributions[_id].addressChain,
            validatedContributions[_id].token,
            validatedContributions[_id].reward,
            validators
        );
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
