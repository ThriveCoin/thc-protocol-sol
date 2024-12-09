// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IBadgeQuery.sol";

/**
 * @title ThriveWorkerUnit
 * @dev Contract of a work unit representing a task where contributors complete and earn rewards.
 */
contract ThriveWorkerUnit {
    address public immutable moderator;
    address public rewardToken;
    uint256 public rewardAmount;
    uint256 public maxRewards;
    uint256 public deadline;
    uint256 public maxCompletionsPerUser;
    uint256 public validationRewardAmount;
    bytes32[] public requiredBadges;
    address[] public validators;
    address public assignedContributor;
    string public validationMetadata;
    string public metadataVersion;
    string public metadata;

    mapping(address => uint256) public completions;

    IBadgeQuery public badgeQuery;

    enum Status {
        Active,
        Expired
    }
    Status public status;

    struct Confirmation {
        address contributor;
        string validationMetadata;
        uint256 rewardAmount;
        address validator;
    }
    Confirmation[] public confirmations;

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
        require(isValidator(msg.sender), "Only a validator can perform this action");
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
        require(_deadline > block.timestamp, "Deadline must be in the future");
        require(_badgeQuery != address(0), "BadgeQuery address is required");

        moderator = _moderator;
        rewardToken = _rewardToken;
        rewardAmount = _rewardAmount;
        maxRewards = _maxRewards;
        deadline = _deadline;
        maxCompletionsPerUser = _maxCompletionsPerUser;
        validators = _validators;
        validationMetadata = _validationMetadata;
        metadataVersion = _metadataVersion;
        metadata = _metadata;
        badgeQuery = IBadgeQuery(_badgeQuery);

        status = Status.Active;
    }

    function isValidator(address user) public view returns (bool) {
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i] == user) {
                return true;
            }
        }
        return false;
    }

    function _confirm(address contributor, string memory inputValidationMetadata) internal virtual {
        require(status == Status.Active, "Work unit is not active");
        require(block.timestamp <= deadline, "Work unit has expired");
        require(
            completions[contributor] < maxCompletionsPerUser,
            "Max completions per user reached"
        );
        require(
            assignedContributor == address(0) || assignedContributor == contributor,
            "Contributor is not eligible for this work unit"
        );

        for (uint256 i = 0; i < requiredBadges.length; i++) {
            require(
                badgeQuery.hasBadge(contributor, requiredBadges[i]),
                "Contributor does not hold the required badge"
            );
        }

        completions[contributor] += 1;

        // contributor
        if (rewardToken == address(0)) {
            require(address(this).balance >= rewardAmount, "Insufficient contract balance");
            payable(contributor).transfer(rewardAmount);
        } else {
            IERC20(rewardToken).transfer(contributor, rewardAmount);
        }

        // validator
        if (rewardToken == address(0)) {
            require(address(this).balance >= validationRewardAmount, "Insufficient contract balance");
            payable(msg.sender).transfer(validationRewardAmount);
        } else {
            IERC20(rewardToken).transfer(msg.sender, validationRewardAmount);
        }

        confirmations.push(
            Confirmation({
                contributor: contributor,
                validationMetadata: inputValidationMetadata,
                rewardAmount: rewardAmount,
                validator: msg.sender
            })
        );

        emit ConfirmationAdded(contributor, inputValidationMetadata, rewardAmount, msg.sender);
    }

    function confirm(address contributor, string memory inputValidationMetadata) external onlyValidator {
        _confirm(contributor, inputValidationMetadata);
    }

    function updateStatus() external {
        if (block.timestamp > deadline) {
            status = Status.Expired;
        }
    }

    function setAssignedContributor(address _assignedContributor) external onlyModerator {
        assignedContributor = _assignedContributor;
        emit MetadataUpdated("assignedContributor", addressToString(_assignedContributor));
    }

    function setRewardToken(address _rewardToken) external onlyModerator {
        rewardToken = _rewardToken;
        emit MetadataUpdated("rewardToken", addressToString(_rewardToken));
    }

    function setRewardAmount(uint256 _rewardAmount) external onlyModerator {
        rewardAmount = _rewardAmount;
        emit ConfigurationUpdated("rewardAmount", _rewardAmount);
    }

    function setMaxRewards(uint256 _maxRewards) external onlyModerator {
        maxRewards = _maxRewards;
        emit ConfigurationUpdated("maxRewards", _maxRewards);
    }

    function setDeadline(uint256 _deadline) external onlyModerator {
        require(_deadline > block.timestamp, "Deadline must be in the future");
        deadline = _deadline;
        emit ConfigurationUpdated("deadline", _deadline);
    }

    function setMaxCompletionsPerUser(uint256 _maxCompletionsPerUser) external onlyModerator {
        maxCompletionsPerUser = _maxCompletionsPerUser;
        emit ConfigurationUpdated("maxCompletionsPerUser", _maxCompletionsPerUser);
    }

    function setValidationRewardAmount(uint256 _validationRewardAmount) external onlyModerator {
        validationRewardAmount = _validationRewardAmount;
        emit ConfigurationUpdated("validationRewardAmount", _validationRewardAmount);
    }

    function setValidators(address[] calldata _validators) external onlyModerator {
        validators = _validators;
        emit MetadataUpdated("validators", "Updated validator list");
    }

    function setValidationMetadata(string calldata _validationMetadata) external onlyModerator {
        validationMetadata = _validationMetadata;
        emit MetadataUpdated("validationMetadata", _validationMetadata);
    }

    function setMetadataVersion(string calldata _metadataVersion) external onlyModerator {
        metadataVersion = _metadataVersion;
        emit MetadataUpdated("metadataVersion", _metadataVersion);
    }

    function setMetadata(string calldata _metadata) external onlyModerator {
        metadata = _metadata;
        emit MetadataUpdated("metadata", _metadata);
    }

    function addressToString(address _addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }

    receive() external payable {}

    fallback() external payable {}
}
