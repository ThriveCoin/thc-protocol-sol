// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AccessControlHelper} from "src/libraries/AccessControlHelper.sol";
import {SignatureHelper} from "src/libraries/SignatureHelper.sol";
import {ThriveBridgeSourceBase} from "./ThriveBridgeSourceBase.sol";

contract ThriveBridgeSourceIERC20 is ThriveBridgeSourceBase {
    using SafeERC20 for IERC20;

    IERC20 public token;

    function initialize(
        address _destContract,
        address _accessControlEnumerable,
        bytes32 _role,
        address _token
    ) public initializer {
        _initialize(_destContract, _accessControlEnumerable, _role);
        token = IERC20(_token);
    }

    function _lockTokens(
        address sender,
        address receiver,
        uint256 amount,
        bytes calldata signature
    ) internal virtual override {
        super._lockTokens(sender, receiver, amount, signature);
        token.safeTransferFrom(sender, address(this), amount);
    }

    function _unlockTokens(
        address sender,
        address receiver,
        uint256 amount,
        uint256 nonce,
        bytes calldata signature
    ) internal virtual override {
        super._unlockTokens(sender, receiver, amount, nonce, signature);
        token.safeTransfer(receiver, amount);
    }
}
