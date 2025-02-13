// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ThriveStakingBase} from "./ThriveStakingBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ThriveStakingIERC20 is ThriveStakingBase {
    /// @notice Initialize with the ERC20 token address and staking parameters.
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

    /// @notice Stake ERC20 tokens. The user must have approved the contract beforehand.
    function _stake(uint256 amount) internal virtual override {
        require(
            amount >= minStakingAmount, "ThriveProtocol: below minimum stake"
        );
        require(
            IERC20(token).transferFrom(msg.sender, address(this), amount),
            "ThriveProtocol: transfer failed"
        );

        super._stake(amount);
    }

    /// @dev Implements token-specific reward transfer for ERC20.
    function _transferReward(address user, uint256 amount) internal override {
        require(
            IERC20(token).transfer(user, amount),
            "ThriveProtocol: reward transfer failed"
        );
    }
}
