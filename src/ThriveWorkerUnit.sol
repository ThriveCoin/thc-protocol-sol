// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ThriveWorkerUnit
 * @dev Contract of a work unit representing a task where contributors complete and earn rewards.
 */
contract ThriveWorkerUnit {
    struct Metadata {
        bytes32 requiredBadge;
        address assignedAddress;
        address validator;
        string validationMetadata;
        uint256 metadataVersion;
        string metadata;
    }

    address public immutable moderator;
    address public immutable rewardToken;
    uint256 public immutable rewardAmount;
    uint256 public immutable maxRewards;
    uint256 public immutable deadline;
    uint256 public immutable maxCompletionsPerUser;

    Metadata public metadataInfo;

    enum Status {
        Active,
        Expired
    }
    Status public status;

    mapping(address => uint256) public completions;
    mapping(address => uint256) public balanceOf;

    event Reward(address indexed recipient, uint256 amount, string reason);
    event Withdrawal(address indexed user, uint256 amount);

    /**
     * @notice Constructor to initialize the work unit.
     * Reduced number of parameters passed to avoid "stack too deep".
     */
    constructor(
        address _moderator,
        address _rewardToken,
        uint256 _rewardAmount,
        uint256 _maxRewards,
        uint256 _deadline,
        uint256 _maxCompletionsPerUser
    ) {
        require(_moderator != address(0), "Moderator address is required");
        require(_deadline > block.timestamp, "Deadline must be in the future");

        moderator = _moderator;
        rewardToken = _rewardToken;
        rewardAmount = _rewardAmount;
        maxRewards = _maxRewards;
        deadline = _deadline;
        maxCompletionsPerUser = _maxCompletionsPerUser;

        status = Status.Active;
    }

    /**
     * @notice Sets the metadata for the work unit. Update after creation also.
     */
    function setMetadata(
        bytes32 _requiredBadge,
        address _assignedAddress,
        address _validator,
        string memory _validationMetadata,
        uint256 _metadataVersion,
        string memory _metadata
    ) external {
        require(msg.sender == moderator, "Only moderator can update metadata");
        metadataInfo = Metadata({
            requiredBadge: _requiredBadge,
            assignedAddress: _assignedAddress,
            validator: _validator,
            validationMetadata: _validationMetadata,
            metadataVersion: _metadataVersion,
            metadata: _metadata
        });
    }

    /**
     * @notice Updates the status of the work unit to Expired if the deadline has passed.
     */
    function updateStatus() external {
        if (block.timestamp > deadline) {
            status = Status.Expired;
        }
    }

    /**
     * @notice Rewards a user for completing the work unit.
     * @param _recipient Address of the contributor.
     * @param _reason Reason for the reward.
     */
    function reward(address _recipient, string calldata _reason) external {
        require(status == Status.Active, "Work unit is not active");
        require(block.timestamp <= deadline, "Work unit has expired");
        require(
            completions[_recipient] < maxCompletionsPerUser,
            "Max completions per user reached"
        );
        require(
            balanceOf[_recipient] + rewardAmount <= maxRewards,
            "Reward pool exceeded"
        );
        if (metadataInfo.assignedAddress != address(0)) {
            require(
                _recipient == metadataInfo.assignedAddress,
                "Work unit restricted to a specific address"
            );
        }

        completions[_recipient] += 1;
        balanceOf[_recipient] += rewardAmount;

        emit Reward(_recipient, rewardAmount, _reason);
    }

    /**
     * @notice Allows a user to withdraw their earned rewards.
     * @param _amount Amount to withdraw.
     */
    function withdraw(uint256 _amount) external {
        require(balanceOf[msg.sender] >= _amount, "Insufficient balance");

        balanceOf[msg.sender] -= _amount;

        if (rewardToken == address(0)) {
            // Native token transfer
            require(address(this).balance >= _amount, "Insufficient contract balance");
            payable(msg.sender).transfer(_amount);
        } else {
            // ERC20 token transfer
            IERC20(rewardToken).transfer(msg.sender, _amount);
        }

        emit Withdrawal(msg.sender, _amount);
    }

    /**
     * @dev Fallback function to receive native tokens.
     */
    receive() external payable {}
}
