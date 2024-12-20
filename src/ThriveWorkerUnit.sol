// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IBadgeQuery.sol";

/**
 * @title ThriveWorkerUnit
 * @dev Contract of a work unit representing a task where contributors complete and earn rewards.
 */
contract ThriveWorkerUnit is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    address public immutable moderator;
    address public immutable rewardToken;
    uint256 public immutable rewardAmount;
    uint256 public immutable maxRewards;
    uint256 public validationRewardAmount;
    address public assignedContributor;
    uint256 public maxCompletionsPerUser;
    uint256 public deadline;
    string public validationMetadata;
    string public metadataVersion;
    string public metadata;

    EnumerableSet.AddressSet private validators;
    EnumerableSet.Bytes32Set private requiredBadges;

    mapping(address => uint256) public completions;

    IBadgeQuery public badgeQuery;
    bool public ready;

    event Initialized();
    event ConfirmationAdded(
        address indexed contributor,
        string validationMetadata,
        uint256 rewardAmount,
        address indexed validator
    );
    event Withdrawn(address token, uint256 amount);

    modifier onlyModerator() {
        require(
            msg.sender == moderator,
            "ThriveProtocol: only the moderator can perform this action"
        );
        _;
    }

    modifier onlyValidator() {
        require(
            validators.contains(msg.sender),
            "ThriveProtocol: only a validator can perform this action"
        );
        _;
    }

    modifier onceReady() {
        require(ready, "ThriveProtocol: contract is not ready");
        _;
    }

    /**
     * @dev Modifier to check if the caller is the ThriveReviewFactory contract.
     * This is - for now - only used to add a ThriveReviewContract as a validator.
     */
    modifier onlyThriveReviewFactory() {
        require(
            msg.sender == address(1234), // @dev this should be the address of the ThriveReviewFactory
            "ThriveProtocol: caller is not the ThriveReviewFactory"
        );
        _;
    }


    constructor(
        address _moderator,
        address _rewardToken,
        uint256 _rewardAmount,
        uint256 _maxRewards,
        uint256 _validationRewardAmount,
        uint256 _deadline,
        uint256 _maxCompletionsPerUser,
        address[] memory _validators,
        address _assignedContributor,
        address _badgeQuery
    ) {
        require(
            _moderator != address(0),
            "ThriveProtocol: moderator address is required"
        );
        require(
            _badgeQuery != address(0),
            "ThriveProtocol: badgeQuery address is required"
        );
        require(
            _deadline > block.timestamp,
            "ThriveProtocol: deadline must be in the future"
        );
        require(_rewardAmount > 0, "ThriveProtocol: invalid reward amount!");
        require(
            _validationRewardAmount > 0,
            "ThriveProtocol: invalid validation reward amount!"
        );

        moderator = _moderator;
        rewardToken = _rewardToken;
        rewardAmount = _rewardAmount;
        maxRewards = _maxRewards;
        validationRewardAmount = _validationRewardAmount;
        deadline = _deadline;
        maxCompletionsPerUser = _maxCompletionsPerUser;

        for (uint256 i = 0; i < _validators.length; i++) {
            validators.add(_validators[i]);
        }

        assignedContributor = _assignedContributor;
        badgeQuery = IBadgeQuery(_badgeQuery);
    }

    function initialize() external payable onlyModerator {
        require(!ready, "ThriveProtocol: already initialized");
        uint256 totalRequiredValue = maxRewards * validationRewardAmount;
        require(
            msg.value >= totalRequiredValue,
            "ThriveProtocol: insufficient value for validators and contributors"
        );
        require(
            IERC20(rewardToken).balanceOf(msg.sender) >=
                rewardAmount * maxRewards,
            "ThriveProtocol: insufficient value for contributors"
        );

        IERC20(rewardToken).safeTransferFrom(
            msg.sender,
            address(this),
            rewardAmount * maxRewards
        );
        ready = true;

        emit Initialized();
    }

    function confirm(
        address contributor,
        string memory inputValidationMetadata
    ) external onlyValidator onceReady nonReentrant {
        require(
            block.timestamp <= deadline,
            "ThriveProtocol: work unit has expired"
        );
        require(
            completions[contributor] < maxCompletionsPerUser,
            "ThriveProtocol: max completions per user reached"
        );
        if (assignedContributor != address(0)) {
            require(
                contributor == assignedContributor,
                "ThriveProtocol: contributor is not the assigned address"
            );
        }

        bool hasAtLeastOneBadge = false;

        for (uint256 i = 0; i < requiredBadges.length(); i++) {
            if (badgeQuery.hasBadge(contributor, requiredBadges.at(i))) {
                hasAtLeastOneBadge = true;
                break;
            }
        }

        require(
            hasAtLeastOneBadge,
            "ThriveProtocol: required badge is missing!"
        );

        completions[contributor]++;
        // contributor
        IERC20(rewardToken).safeTransfer(contributor, rewardAmount);
        // validator
        (bool success, ) = msg.sender.call{value: validationRewardAmount}("");
        require(success, "ThriveProtocol: Ether transfer to validator failed");

        emit ConfirmationAdded(
            contributor,
            inputValidationMetadata,
            rewardAmount,
            msg.sender
        );
    }

    function setAssignedContributor(
        address _assignedContributor
    ) external onlyModerator {
        require(
            _assignedContributor != address(0),
            "ThriveProtocol: invalid address!"
        );
        assignedContributor = _assignedContributor;
    }




    /**
     * Added as a safety module so that ThriveReviewContract can be added as a validator at a later point in time if needed
     * Also, should this be allowed to be called only once?
     * @param validator Address of the ThriveReviewContract to add as a validator.
     */
    function addValidator(address validator) external onlyThriveReviewFactory {
        validators.add(validator);
    }


    function addRequiredBadge(bytes32 badge) external onlyModerator {
        requiredBadges.add(badge);
    }

    function removeRequiredBadge(bytes32 badge) external onlyModerator {
        require(
            requiredBadges.contains(badge),
            "ThriveProtocol: badge does not exist"
        );
        requiredBadges.remove(badge);
    }

    function setValidationMetadata(
        string calldata _validationMetadata
    ) external onlyModerator {
        validationMetadata = _validationMetadata;
    }

    function setMetadataVersion(
        string calldata _metadataVersion
    ) external onlyModerator {
        metadataVersion = _metadataVersion;
    }

    function setMetadata(string calldata _metadata) external onlyModerator {
        metadata = _metadata;
    }

    function setDeadline(uint256 _deadline) external onlyModerator {
        require(
            _deadline > block.timestamp,
            "ThriveProtocol: deadline must be in the future"
        );
        deadline = _deadline;
    }

    function setMaxCompletionsPerUser(
        uint256 _maxCompletionsPerUser
    ) external onlyModerator {
        maxCompletionsPerUser = _maxCompletionsPerUser;
    }

    function withdrawRemaining() external onlyModerator {
        require(
            block.timestamp > deadline,
            "ThriveProtocol: work unit is still active"
        );

        uint256 remainingERC20 = IERC20(rewardToken).balanceOf(address(this));
        if (remainingERC20 > 0) {
            IERC20(rewardToken).safeTransfer(moderator, remainingERC20);
            emit Withdrawn(rewardToken, remainingERC20);
        }

        uint256 remainingEther = address(this).balance;
        if (remainingEther > 0) {
            (bool success, ) = payable(moderator).call{value: remainingEther}(
                ""
            );
            require(
                success,
                "ThriveProtocol: Ether transfer to validator failed"
            );
            emit Withdrawn(address(0), remainingEther);
        }
    }

    function getValidators() external view returns (address[] memory) {
        return validators.values();
    }

    function getRequiredBadges() external view returns (bytes32[] memory) {
        return requiredBadges.values();
    }

    function status() external view returns (string memory) {
        return block.timestamp <= deadline ? "active" : "expired";
    }

    /**
     * @notice Checks if an address is a moderator.
     * @param account Account address to check.
     * @return True if the address is a moderator, false otherwise.
     */
    function isModerator(address account) external view returns (bool) {
        return account == moderator;
    }

    receive() external payable {}
}
