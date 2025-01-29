// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {StakingBase} from "./ThriveStakingBase.sol";

contract ThriveStakingNative is ThriveStakingBase {
    function initialize(
        uint256 _rewardRate,
        uint256 _minStakingAmount,
        address _accessControlEnumerable,
        bytes32 _role
    ) public initializer {
        _initialize(
            address(0),
            _rewardRate,
            _minStakingAmount,
            _accessControlEnumerable,
            _role
        );
    }

    function stake() external payable nonReentrant {
        require(
            msg.value >= minStakingAmount, "ThriveProtocol: below minimum stake"
        );

        StakingDetails storage details = stakers[msg.sender];
        details.amount += msg.value;
        details.stakingTime = block.timestamp;
        details.lastRewardTime = block.timestamp;

        emit Staked(msg.sender, msg.value);
    }

    function withdraw() external nonReentrant {
        StakingDetails storage details = stakers[msg.sender];
        require(details.amount > 0, "ThriveProtocol: no staked tokens");
        require(
            block.timestamp >= details.stakingTime + MIN_STAKING_PERIOD,
            "ThriveProtocol: 30-day lockup"
        );

        uint256 reward = calculateReward(msg.sender);
        uint256 totalAmount = details.amount + reward;

        (bool success,) = payable(msg.sender).call{value: totalAmount}("");
        require(success, "ThriveProtocol: withdraw failed");
        emit Withdrawn(msg.sender, details.amount, reward);

        details.amount = 0;
        details.stakingTime = 0;
        details.lastRewardTime = 0;
    }
}
