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

/**
 * @title ThriveBridgeSourceERC20
 * @notice This contract manages...
 */
contract ThriveBridgeSourceERC20 is ThriveBridgeSourceBase {
    using SafeERC20 for IERC20;

    IERC20 public token;

    /**
     * @dev Initializes the contract.
     * @param _accessControlEnumerable The address of the AccessControlEnumerable contract.
     * @param _role The access control role.
     * @param _token The address of ERC20 token contract.
     */
    function initialize(
        address _destContract,
        address _accessControlEnumerable,
        bytes32 _role,
        address _token
    ) public initializer {
        initialize(_destContract, _accessControlEnumerable, _role);
        token = IERC20(_token);
    }

    function _lockTokens(
        address sender,
        address receiver,
        uint256 amount,
        bytes calldata signature
    ) internal virtual override nonReentrant {
        super._lockTokens(sender, receiver, amount, signature);
        token.safeTransferFrom(sender, address(this), amount);
    }

    function _unlockTokens(
        address sender,
        address receiver,
        uint256 amount,
        uint256 nonce,
        bytes calldata signature
    ) internal virtual override nonReentrant {
        super._unlockTokens(sender, receiver, amount, nonce, signature);
        token.safeTransfer(receiver, amount);
    }
}
