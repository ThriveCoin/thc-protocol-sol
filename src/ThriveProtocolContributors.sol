//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {AccessControlHelper} from "src/libraries/AccessControlHelper.sol";

contract ThriveProtocolContributors {
    using AccessControlHelper for IAccessControlEnumerable;

    IAccessControlEnumerable public accessControlEnumerable;
    bytes32 role;

    event ValidatedContributionAdded(
        uint indexed id,
        uint contribution_id,
        string metadata_identifier,
        string validator_address,
        string address_chain,
        string token,
        uint reward,
        ValidatorReward[] validators
    );

    struct ValidatorReward {
        address validator;
        uint256 reward;
    }

    struct ValidatedContribution {
        uint contribution_id;
        string metadata_identifier;
        string validator_address;
        string address_chain;
        string token;
        uint reward;
        uint validatorsCount;
        mapping(uint => ValidatorReward) validators;
    }

    uint256 private _validatedContributionCount;

    mapping(uint256 id => ValidatedContribution contribution)
        private contributions;

    constructor(address _accessControlEnumerable, bytes32 _role) {
        accessControlEnumerable = IAccessControlEnumerable(
            _accessControlEnumerable
        );
        role = _role;
    }

    modifier onlyAdmin() {
        accessControlEnumerable.checkRole(role, msg.sender);
        _;
    }

    function validatedContributionCount() public view returns (uint256) {
        return _validatedContributionCount;
    }

    function addValidatedContribution(
        uint _contribution_id,
        string memory _metadata_identifier,
        string memory _validator_address,
        string memory _address_chain,
        string memory _token,
        uint _reward,
        address[] memory _validator_addresses,
        uint[] memory _validator_rewards
    ) public returns (bool success) {
        require(
            _validator_addresses.length == _validator_rewards.length,
            "Array lengths mismatch"
        );
        ValidatedContribution storage contribution = contributions[
            _contribution_id
        ];
        contribution.contribution_id = _contribution_id;
        contribution.metadata_identifier = _metadata_identifier;
        contribution.validator_address = _validator_address;
        contribution.address_chain = _address_chain;
        contribution.token = _token;
        contribution.reward = _reward;

        ValidatorReward[] memory validators = new ValidatorReward[](
            _validator_addresses.length
        );
        for (uint256 i = 0; i < _validator_addresses.length; i++) {
            ValidatorReward memory reward = ValidatorReward({
                validator: _validator_addresses[i],
                reward: _validator_rewards[i]
            });
            contribution.validators[i] = reward;
            contribution.validatorsCount++;
            validators[i] = reward;
        }

        _validatedContributionCount++;

        emit ValidatedContributionAdded(
            _validatedContributionCount,
            contribution.contribution_id,
            contribution.metadata_identifier,
            contribution.validator_address,
            contribution.address_chain,
            contribution.token,
            contribution.reward,
            validators
        );

        return true;
    }

    function getValidatedContribution(
        uint _id
    )
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
        ValidatorReward[] memory validators = new ValidatorReward[](
            contributions[_id].validatorsCount
        );
        for (uint256 i = 0; i < validators.length; i++) {
            validators[i] = contributions[_id].validators[i];
        }

        return (
            contributions[_id].contribution_id,
            contributions[_id].metadata_identifier,
            contributions[_id].validator_address,
            contributions[_id].address_chain,
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
     */
    function setAccessControlEnumerable(
        address _accessControlEnumerable
    ) external onlyAdmin {
        accessControlEnumerable = IAccessControlEnumerable(
            _accessControlEnumerable
        );
    }
}
