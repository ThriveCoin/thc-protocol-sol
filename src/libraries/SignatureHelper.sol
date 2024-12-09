//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from
    "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

library SignatureHelper {
    function hashBridgeRequest(
        address destContract,
        address sender,
        address receiver,
        uint256 nonce,
        uint256 amount
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(destContract, sender, receiver, nonce, amount)
        );
    }

    function recoverSigner(bytes32 hash, bytes memory signature)
        internal
        pure
        returns (address)
    {
        return ECDSA.recover(hash, signature);
    }

    function verifyBridgeRequest(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (bool) {
        address recoveredSigner = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(hash), signature
        );
        return signer == recoveredSigner;
    }
}
