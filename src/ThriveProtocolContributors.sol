//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import {AccessControlHelper} from "src/libraries/AccessControlHelper.sol";
import {ThriveProtocolContributions} from "src/ThriveProtocolContributions.sol";
import {UUPSUpgradeable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ThriveProtocolContributors is OwnableUpgradeable, UUPSUpgradeable {
    ThriveProtocolContributions public contributions;

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

    function initialize(address _contributions) public initializer {
        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();

        contributions = ThriveProtocolContributions(_contributions);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    modifier onlyContributionValidator(uint256 _contributionId) {
        (,,,, address validator,,,) =
            contributions.contributions(_contributionId);
        require(
            validator == msg.sender,
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
}
