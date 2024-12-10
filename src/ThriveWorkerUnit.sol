// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./IBadgeQuery.sol";

/**
 * @title ThriveWorkerUnit
 * @dev Contract of a work unit representing a task where contributors complete and earn rewards.
 */
contract ThriveWorkerUnit {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    address public immutable moderator;
    address public immutable rewardToken;
    uint256 public immutable rewardAmount;
    uint256 public immutable maxRewards;
    uint256 public immutable validationRewardAmount;
    uint256 public maxCompletionsPerUser;
    uint256 public deadline;

    IBadgeQuery public badgeQuery;
    bool public ready;

    string public validationMetadata;
    string public metadataVersion;
    string public metadata;

    EnumerableSet.AddressSet private validators;
    EnumerableSet.Bytes32Set private requiredBadges;
    mapping(address => uint256) public completions;

    event Initialized();
    event ConfirmationAdded(
        address indexed contributor,
        string validationMetadata,
        uint256 rewardAmount,
        address indexed validator
    );

    event ConfigurationUpdated(string field, uint256 newValue);
    event MetadataUpdated(string field, string newValue);

    modifier onlyModerator() {
        require(msg.sender == moderator, "Only the moderator can perform this action");
        _;
    }

    modifier onlyValidator() {
        require(validators.contains(msg.sender), "Only a validator can perform this action");
        _;
    }

    modifier onceReady() {
        require(ready, "Contract is not ready");
        _;
    }

    constructor(
        address _moderator,
        address _rewardToken,
        uint256 _rewardAmount,
        uint256 _maxRewards,
        uint256 _deadline,
        uint256 _maxCompletionsPerUser,
        address[] memory _validators,
        string memory _validationMetadata,
        string memory _metadataVersion,
        string memory _metadata,
        address _badgeQuery
    ) {
        require(_moderator != address(0), "Moderator address is required");
        require(_badgeQuery != address(0), "BadgeQuery address is required");
        require(_deadline > block.timestamp, "Deadline must be in the future");

        moderator = _moderator;
        rewardToken = _rewardToken;
        rewardAmount = _rewardAmount;
        maxRewards = _maxRewards;
        validationRewardAmount = _rewardAmount / 10; // Validators = 10% of contributor reward
        deadline = _deadline;
        maxCompletionsPerUser = _maxCompletionsPerUser;

        for (uint256 i = 0; i < _validators.length; i++) {
            validators.add(_validators[i]);
        }

        validationMetadata = _validationMetadata;
        metadataVersion = _metadataVersion;
        metadata = _metadata;
        badgeQuery = IBadgeQuery(_badgeQuery);
    }

    function initialize() external payable onlyModerator {
        uint256 requiredEther = validators.length() * validationRewardAmount;
        require(msg.value >= requiredEther, "Insufficient Ether for validators");
        require(IERC20(rewardToken).balanceOf(msg.sender) >= rewardAmount * maxRewards, "Insufficient ERC20 for contributors");

        IERC20(rewardToken).transferFrom(msg.sender, address(this), rewardAmount * maxRewards);
        ready = true;

        emit Initialized();
    }

    function confirm(address contributor, string memory inputValidationMetadata) external onlyValidator onceReady {
        require(block.timestamp <= deadline, "Work unit has expired");
        require(completions[contributor] < maxCompletionsPerUser, "Max completions per user reached");

        for (uint256 i = 0; i < requiredBadges.length(); i++) {
            require(badgeQuery.hasBadge(contributor, requiredBadges.at(i)), "Contributor lacks required badge");
        }

        completions[contributor]++;
        // contributor
        IERC20(rewardToken).transfer(contributor, rewardAmount);
        // validator
        payable(msg.sender).transfer(validationRewardAmount);

        emit ConfirmationAdded(contributor, inputValidationMetadata, rewardAmount, msg.sender);
    }

    function addValidator(address _validator) external onlyModerator {
        validators.add(_validator);
    }

    function removeValidator(address _validator) external onlyModerator {
        validators.remove(_validator);
    }

    function addRequiredBadge(bytes32 badge) external onlyModerator {
        requiredBadges.add(badge);
    }

    function removeRequiredBadge(bytes32 badge) external onlyModerator {
        requiredBadges.remove(badge);
    }

    function getValidators() external view returns (address[] memory) {
        return validators.values();
    }

    function getRequiredBadges() external view returns (bytes32[] memory) {
        return requiredBadges.values();
    }

    receive() external payable {}
}
