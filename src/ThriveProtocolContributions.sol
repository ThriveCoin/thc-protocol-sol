// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ThriveProtocolContributions {
    uint256 internal _contributionCount;

    /**
     * @dev Emitted when a contribution is added
     */
    event ContributionAdded(
        uint indexed _id,
        address indexed _owner,
        string indexed _community,
        string _communityChain,
        string _metadataURI,
        address _validator,
        uint _reward,
        uint _validationReward
    );

    /**
     * @dev Emitted when a contribution is deactivated
     */
    event ContributionDeactivated(uint indexed _id);

    enum Status {
        Active,
        Inactive
    }

    /**
     * @dev The main data structure that will hold the information regarding the contribution
     */
    struct Contribution {
        address owner;
        string community;
        string communityChain;
        string metadataURI;
        address validator;
        uint reward;
        uint validationReward;
        Status status;
    }

    mapping(uint256 id => Contribution contribution) public contributions;

    /**
     * @notice Returns the number of contributions created
     */
    function contributionCount() external view returns (uint256) {
        return _contributionCount;
    }

    /**
     * @notice Adds a new contribution and increases the  contributionCount, the added contribution should have an active state.
     * @param _community The name of the community
     * @param _communityChain The chain of the comminity
     * @param _metadataURI Metadata indentifier
     * @param _validator The address of validator
     * @param _reward The value of reward
     * @param _validationReward The value of validation reward
     */
    function addContribution(
        string memory _community,
        string memory _communityChain,
        string memory _metadataURI,
        address _validator,
        uint _reward,
        uint _validationReward
    ) public returns (bool success) {
        contributions[_contributionCount] = Contribution(
            msg.sender,
            _community,
            _communityChain,
            _metadataURI,
            _validator,
            _reward,
            _validationReward,
            Status.Active
        );
        emit ContributionAdded(
            _contributionCount,
            msg.sender,
            _community,
            _communityChain,
            _metadataURI,
            _validator,
            _reward,
            _validationReward
        );
        _contributionCount++;
        return true;
    }

    /**
     * @notice Returns information of a specific contribution
     */
    function getContribution(uint _id)
        public
        view
        returns (
            address,
            string memory,
            string memory,
            string memory,
            address,
            uint,
            uint,
            Status
        )
    {
        Contribution memory contribution = contributions[_id];
        return (
            contribution.owner,
            contribution.community,
            contribution.communityChain,
            contribution.metadataURI,
            contribution.validator,
            contribution.reward,
            contribution.validationReward,
            contribution.status
        );
    }

    /**
     * @notice Changes the status of a given contribution to  Inactive
     * @param _id The id of contribution
     */
    function deactivateContribution(uint _id) public returns (bool success) {
        Contribution storage contribution = contributions[_id];
        require(
            msg.sender == contribution.owner, "ThriveProtocol: not an owner"
        );
        require(
            contribution.status == Status.Active,
            "ThriveProtocol: contribution already deactivated"
        );
        contribution.status = Status.Inactive;
        emit ContributionDeactivated(_id);
        return true;
    }
}
