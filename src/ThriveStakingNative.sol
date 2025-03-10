// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ThriveStakingBase} from "./ThriveStakingBase.sol";

contract ThriveStakingNative is ThriveStakingBase {
    /// @notice Initialize for native token staking. The token address is set to address(0).
    function initialize(
        uint256 _yieldRate,
        uint256 _minStakingAmount,
        uint256 _epochDuration,
        uint256 _halfEpochDuration,
        address _accessControlEnumerable,
        bytes32 _role
    ) public initializer {
        _initialize(
            address(0),
            _yieldRate,
            _minStakingAmount,
            _epochDuration,
            _halfEpochDuration,
            _accessControlEnumerable,
            _role
        );
    }

    /// @dev Overrides base `_stake()`
    function _stake(uint256 amount) internal virtual override {
        require(
            amount == msg.value,
            "ThriveProtocol: Amount mismatch with value sent"
        );
        require(
            msg.value >= minStakingAmount, "ThriveProtocol: below minimum stake"
        );
        super._stake(amount);
    }

    /**
     * @dev Transfers the staked principal as native tokens.
     */
    function _transferAmountStaked(address user, uint256 amount)
        internal
        override
    {
        (bool success,) = user.call{value: amount}("");
        require(success, "Native staked amount transfer failed");
    }

    // Accept native token transfers
    receive() external payable {}
}
