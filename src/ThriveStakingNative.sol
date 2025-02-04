// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ThriveStakingBase} from "./ThriveStakingBase.sol";

contract ThriveStakingNative is ThriveStakingBase {
    /// @notice Initialize for native token staking. The token address is set to address(0).
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

    /// @notice Stake native tokens by sending ETH along with the call.
    function stake() external payable nonReentrant {
        require(
            msg.value >= minStakingAmount, "ThriveProtocol: below minimum stake"
        );

        _stake(msg.value);
    }

    /// @dev Implements token-specific reward transfer for native tokens.
    function _transferReward(address user, uint256 amount) internal override {
        (bool success,) = payable(user).call{value: amount}("");
        require(success, "ThriveProtocol: native reward transfer failed");
    }

    // Accept native token transfers
    receive() external payable {}
}
