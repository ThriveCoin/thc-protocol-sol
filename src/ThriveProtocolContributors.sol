//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import {AccessControlHelper} from "src/libraries/AccessControlHelper.sol";

contract ThriveProtocolContributors {
    using AccessControlHelper for IAccessControlEnumerable;

    IAccessControlEnumerable public accessControlEnumerable;
    bytes32 public adminRole;

    event ValidatedContributionAdded(
        uint indexed id,
        uint contributionId,
        string metadataIdentifier,
        string endEntityAddress,
        string addressChain,
        string token,
        uint reward,
        ValidatorReward[] validators
    );

    struct ValidatorReward {
        address validator;
        uint256 reward;
    }

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

    uint256 private _validatedContributionCount;

    mapping(uint256 id => ValidatedContribution contribution) private
        contributions;

    constructor(address _accessControlEnumerable, bytes32 _role) {
        accessControlEnumerable =
            IAccessControlEnumerable(_accessControlEnumerable);
        adminRole = _role;
    }

    modifier onlyAdmin() {
        accessControlEnumerable.checkRole(adminRole, msg.sender);
        _;
    }

    function validatedContributionCount() public view returns (uint256) {
        return _validatedContributionCount;
    }

    function addValidatedContribution(
        uint _contributionId,
        string memory _metadataIdentifier,
        string memory _endEntityAddress,
        string memory _addressChain,
        string memory _token,
        uint _reward,
        ValidatorReward[] memory _validatorsRewards
    ) public onlyAdmin returns (bool success) {
        // require(
        //     _validatorAddresses.length == _validatorRewards.length,
        //     "Array lengths mismatch"
        // );
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
     */
    function setAccessControlEnumerable(address _accessControlEnumerable, bytes32 _adminRole)
        external
        onlyAdmin
    {
        accessControlEnumerable =
            IAccessControlEnumerable(_accessControlEnumerable);
        adminRole = _adminRole;
    }
}
