// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ThriveStakingBase} from "./ThriveStakingBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ThriveStakingIERC20 is ThriveStakingBase {
    using SafeERC20 for IERC20;
    /// @notice Initialize with the ERC20 token address and staking parameters.

    function initialize(
        address _erc20Token,
        uint256 _yieldRate,
        uint256 _minStakingAmount,
        address _accessControlEnumerable,
        bytes32 _role
    ) public initializer {
        _initialize(
            _erc20Token,
            _yieldRate,
            _minStakingAmount,
            _accessControlEnumerable,
            _role
        );
    }

    /// @notice Stake ERC20 tokens. The user must have approved the contract beforehand.
    function _stake(uint256 amount) internal virtual override {
        require(
            msg.value == 0,
            "ThriveProtocol: native should not be sent for ERC20 staking"
        );
        require(
            amount >= minStakingAmount, "ThriveProtocol: below minimum stake"
        );
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        super._stake(amount);
    }

    /// @dev Implements yield transfer for ERC20 token.
    function _transferYield(address user, uint256 amount) internal override {
        IERC20(token).safeTransfer(user, amount);
    }
}
