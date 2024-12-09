// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";

import {AccessControlHelper} from "src/libraries/AccessControlHelper.sol";
import {SignatureHelper} from "src/libraries/SignatureHelper.sol";
import {ThriveBridgeSourceBase} from "./ThriveBridgeSourceBase.sol";

/**
 * @title ThriveBridgeSourceERC20
 * @notice This contract manages...
 */
contract ThriveBridgeSourceNative is ThriveBridgeSourceBase {
    function _lockTokens(
        address sender,
        address receiver,
        uint256 amount,
        bytes calldata signature
    ) internal virtual override nonReentrant {
        super._lockTokens(sender, receiver, amount, signature);
        require(
            msg.value == amount,
            "ThriveProtocol: amount must match received value"
        );
    }

    function _unlockTokens(
        address sender,
        address receiver,
        uint256 amount,
        uint256 nonce,
        bytes calldata signature
    ) internal virtual override nonReentrant {
        super._unlockTokens(sender, receiver, amount, nonce, signature);
        payable(receiver).transfer(amount);
    }
}
