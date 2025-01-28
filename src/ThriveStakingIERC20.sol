// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {StakingBase} from "./ThriveStakingBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20Staking is StakingBase {
    constructor(
        address _moderator,
        address _erc20Token,
        uint256 _rewardRate,
        uint256 _minStakingAmount
    ) StakingBase(_moderator, _erc20Token, _rewardRate, _minStakingAmount) {
        // Constructor initializes the staking parameters
    }

    // Stake IERC20 tokens
    function stake(uint256 amount, address token) external nonReentrant {
        require(
            amount >= minStakingAmount, "ThriveProtocol: below minimum stake"
        );
        require(
            IERC20(token).transferFrom(msg.sender, address(this), amount),
            "ThriveProtocol: stake failed"
        );

        StakingDetails storage details = stakers[msg.sender];
        details.amount += amount;
        details.stakingTime = block.timestamp;
        details.lastRewardTime = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    // Withdraw IERC20 tokens and rewards
    function withdraw(address token) external nonReentrant {
        StakingDetails storage details = stakers[msg.sender];
        require(details.amount > 0, "ThriveProtocol: no staked tokens");
        require(
            block.timestamp >= details.stakingTime + MIN_STAKING_PERIOD,
            "ThriveProtocol: 30-day lockup"
        );

        uint256 reward = calculateReward(msg.sender);
        uint256 totalAmount = details.amount + reward;

        // Transfer staked amount + reward back to the user
        require(
            IERC20(token).transfer(msg.sender, totalAmount),
            "ThriveProtocol: withdraw failed"
        );

        emit Withdrawn(msg.sender, details.amount, token);

        // Reset staker details
        details.amount = 0;
        details.stakingTime = 0;
        details.lastRewardTime = 0;
    }
}
