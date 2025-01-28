// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from
    "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract StakingBase is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct StakingDetails {
        uint256 amount;
        uint256 stakingTime;
        uint256 lastRewardTime;
        uint256 totalRewards;
    }

    address public immutable moderator; // Moderator address
    address public stakingToken; // Staking token (ERC20 or native)
    uint256 public rewardRate; // Annual reward rate (e.g., 10% = 10)
    uint256 public minStakingAmount; // Minimum staking amount
    uint256 public constant MIN_STAKING_PERIOD = 30 days; // Minimum staking period

    mapping(address => StakingDetails) public stakers;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, address token);
    event RewardsClaimed(address indexed user, uint256 reward);

    modifier onlyModerator() {
        require(
            msg.sender == moderator,
            "ThriveProtocol: only the moderator can perform this action"
        );
        _;
    }

    constructor(
        address _moderator,
        address _stakingToken,
        uint256 _rewardRate,
        uint256 _minStakingAmount
    ) {
        require(_moderator != address(0), "ThriveProtocol: invalid moderator");
        moderator = _moderator;
        stakingToken = _stakingToken;
        rewardRate = _rewardRate;
        minStakingAmount = _minStakingAmount;
    }

    // Calculate rewards for a user
    function calculateReward(address user) public view returns (uint256) {
        StakingDetails storage details = stakers[user];
        if (details.amount == 0) return 0;

        uint256 stakingDuration = block.timestamp - details.lastRewardTime;
        return
            (details.amount * rewardRate * stakingDuration) / (365 days * 100);
    }

    // Claim rewards without unstaking
    function claimRewards() external nonReentrant {
        StakingDetails storage details = stakers[msg.sender];
        require(details.amount > 0, "ThriveProtocol: no staked tokens");

        uint256 reward = calculateReward(msg.sender);
        require(reward > 0, "ThriveProtocol: no rewards to claim");

        if (stakingToken == address(0)) {
            // Native token rewards
            (bool success,) = msg.sender.call{value: reward}("");
            require(success, "ThriveProtocol: native token transfer failed");
        } else {
            // ERC20 token rewards
            IERC20(stakingToken).safeTransfer(msg.sender, reward);
        }

        details.lastRewardTime = block.timestamp;
        details.totalRewards += reward;

        emit RewardsClaimed(msg.sender, reward);
    }

    // Update reward rate
    function updateRewardRate(uint256 newRewardRate) external onlyModerator {
        rewardRate = newRewardRate;
    }

    // Withdraw remaining tokens (native or ERC20)
    function withdrawRemaining(address _token)
        external
        onlyModerator
        nonReentrant
    {
        if (_token == address(0)) {
            // Native token withdrawal
            uint256 remainingEther = address(this).balance;
            require(remainingEther > 0, "ThriveProtocol: no native tokens left");
            (bool success,) = payable(moderator).call{value: remainingEther}("");
            require(success, "ThriveProtocol: native withdraw failed");
            emit Withdrawn(moderator, remainingEther, _token);
        } else {
            // ERC20 token withdrawal
            uint256 remainingERC20 = IERC20(_token).balanceOf(address(this));
            require(remainingERC20 > 0, "ThriveProtocol: no ERC20 tokens left");
            IERC20(_token).safeTransfer(moderator, remainingERC20);
            emit Withdrawn(moderator, remainingERC20, _token);
        }
    }

    receive() external payable {}
}
