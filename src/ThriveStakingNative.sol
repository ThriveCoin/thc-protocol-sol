// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {StakingBase} from "./ThriveStakingBase.sol";

contract NativeStaking is StakingBase {
    constructor(address _moderator, address _thriveToken, uint256 _rewardRate)
        StakingBase(_moderator, _thriveToken, _rewardRate, 21 * 1e18)
    {
        // Enforces a 21 THRIVE minimum stake (assuming 18 decimals)
    }

    // Stake Native tokens
    function stake() external payable nonReentrant {
        require(
            msg.value >= minStakingAmount,
            "ThriveProtocol: minimum stake is 21 THRIVE"
        );

        StakingDetails storage details = stakers[msg.sender];
        details.amount += msg.value;
        details.stakingTime = block.timestamp;
        details.lastRewardTime = block.timestamp;

        emit Staked(msg.sender, msg.value);
    }

    // Withdraw Native tokens and rewards
    function withdraw() external nonReentrant {
        StakingDetails storage details = stakers[msg.sender];
        require(details.amount > 0, "ThriveProtocol: no staked tokens");
        require(
            block.timestamp >= details.stakingTime + MIN_STAKING_PERIOD,
            "ThriveProtocol: 30-day lockup"
        );

        uint256 reward = calculateReward(msg.sender);
        uint256 totalAmount = details.amount + reward;

        // Reset staker details
        details.amount = 0;
        details.stakingTime = 0;
        details.lastRewardTime = 0;

        // Transfer native tokens (staked amount + rewards)
        (bool success,) = payable(msg.sender).call{value: totalAmount}("");
        require(success, "ThriveProtocol: withdraw failed");

        emit Withdrawn(msg.sender, totalAmount, address(0));
    }
}
