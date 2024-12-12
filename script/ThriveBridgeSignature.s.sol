//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {SignatureHelper} from "src/libraries/SignatureHelper.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from
    "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract DummyERC20Script is Script {
    function setUp() public {}

    function run(
        address _contract,
        address sender,
        address receiver,
        uint256 nonce,
        uint256 amount,
        bytes memory signature
    ) external {
        bytes32 hash = SignatureHelper.hashBridgeRequest(
            _contract, sender, receiver, nonce, amount
        );
        console2.logBytes32(hash);

        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        console2.logBytes32(ethSignedMessageHash);

        address recovered = ECDSA.recover(ethSignedMessageHash, signature);
        console2.logAddress(recovered);

        console2.logBool(
            SignatureHelper.verifyBridgeRequest(sender, hash, signature)
        );
    }
}
