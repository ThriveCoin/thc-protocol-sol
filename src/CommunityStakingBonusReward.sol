// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract CommunityStakingBonusReward is OwnableUpgradeable, UUPSUpgradeable {
    address public thriveStakingContract;
    uint256 public community_id;
    mapping(address => uint256) public userRewardPercentage;
    mapping(address => uint256) public userClaimed;

    event RewardClaimed(address indexed user, uint256 amount);
    event ContributionUpdated(address indexed user, uint256 percentage);
    event ContributionDataRequested(address indexed user, uint256 communityId);

    function initialize(address _thriveStaking, uint256 _communityId)
        external
        initializer
    {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        thriveStakingContract = _thriveStaking;
        community_id = _communityId;
    }

    /// @notice Oracle updates contribution percentages based on community_id
    function fulfillContributionData(address user, uint256 percentage)
        external
        onlyOwner
    {
        userRewardPercentage[user] = percentage;
        emit ContributionUpdated(user, percentage);
    }

    /// @notice User claims their reward in native tokens
    function claimReward() external {
        if (userRewardPercentage[msg.sender] == 0) {
            emit ContributionDataRequested(msg.sender, community_id);
            return;
        }

        uint256 contractBalance = address(this).balance;
        uint256 userPercentage = userRewardPercentage[msg.sender];
        uint256 reward = (contractBalance * userPercentage) / 100;

        require(reward > 0, "Insufficient pool balance");

        userClaimed[msg.sender] += reward;
        userRewardPercentage[msg.sender] = 0; // Reset after claiming

        (bool success,) = payable(msg.sender).call{value: reward}("");
        require(success, "Reward transfer failed");

        emit RewardClaimed(msg.sender, reward);
    }

    function deposit() external payable onlyOwner {}

    receive() external payable {}

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}
