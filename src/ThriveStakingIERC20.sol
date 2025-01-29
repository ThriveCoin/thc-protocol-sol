// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {StakingBase} from "./ThriveStakingBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ThriveStakingIERC20 is ThriveStakingBase {
    function initialize(
        address _erc20Token,
        uint256 _rewardRate,
        uint256 _minStakingAmount,
        address _accessControlEnumerable,
        bytes32 _role
    ) public initializer {
        _initialize(
            _erc20Token,
            _rewardRate,
            _minStakingAmount,
            _accessControlEnumerable,
            _role
        );
    }

    function stake(uint256 amount) external nonReentrant {
        require(
            amount >= minStakingAmount, "ThriveProtocol: below minimum stake"
        );
        require(
            IERC20(token).transferFrom(msg.sender, address(this), amount),
            "ThriveProtocol: transfer failed"
        );

        StakingDetails storage details = stakers[msg.sender];
        details.amount += amount;
        details.stakingTime = block.timestamp;
        details.lastRewardTime = block.timestamp;

        emit Staked(msg.sender, amount);
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

        require(
            IERC20(token).transfer(msg.sender, totalAmount),
            "ThriveProtocol: withdraw failed"
        );
        emit Withdrawn(msg.sender, details.amount, reward);

        details.amount = 0;
        details.stakingTime = 0;
        details.lastRewardTime = 0;
    }
}
