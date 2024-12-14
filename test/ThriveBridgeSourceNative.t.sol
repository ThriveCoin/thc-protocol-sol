// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ThriveBridgeSourceNative} from "../src/ThriveBridgeSourceNative.sol";
import {ThriveBridgeDestination} from "../src/ThriveBridgeDestination.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";
import {ThriveIERC20Wrapper} from "src/ThriveIERC20Wrapper.sol";
import {SignatureHelper} from "src/libraries/SignatureHelper.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from
    "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract ThriveBridgeSourceNativeTest is Test {
    event TokenLocked(
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        uint256 timestamp,
        uint256 nonce,
        bytes signature
    );

    event TokenUnlocked(
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        uint256 timestamp,
        uint256 nonce,
        bytes signature
    );

    bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 OTHER_ADMIN_ROLE = keccak256("OTHER_ADMIN_ROLE");

    ThriveBridgeSourceNative public srcBridge;
    ThriveBridgeDestination public destBridge;
    ThriveProtocolAccessControl public accessControl;
    ThriveIERC20Wrapper public destToken;

    uint256 privKey1 = uint256(1);
    address addr1 = vm.addr(privKey1);
    uint256 privKey2 = uint256(2);
    address addr2 = vm.addr(privKey2);

    function setUp() public {
        vm.startPrank(addr1);

        ThriveProtocolAccessControl accessControlImpl =
            new ThriveProtocolAccessControl();
        bytes memory accessControlData =
            abi.encodeCall(accessControlImpl.initialize, ());
        address accessControlProxy = address(
            new ERC1967Proxy(address(accessControlImpl), accessControlData)
        );
        accessControl = ThriveProtocolAccessControl(accessControlProxy);
        accessControl.grantRole(ADMIN_ROLE, addr1);

        destToken = new ThriveIERC20Wrapper("DDUMMY", "DDM", 18);

        ThriveBridgeSourceNative bridgeSrcImpl = new ThriveBridgeSourceNative();
        bytes memory bridgeSrcData = abi.encodeCall(
            bridgeSrcImpl.initialize,
            (address(0), address(accessControl), ADMIN_ROLE)
        );
        address bridgeSrcProxy =
            address(new ERC1967Proxy(address(bridgeSrcImpl), bridgeSrcData));
        srcBridge = ThriveBridgeSourceNative(bridgeSrcProxy);

        ThriveBridgeDestination bridgeDestImpl = new ThriveBridgeDestination();
        bytes memory bridgeDestData = abi.encodeCall(
            bridgeDestImpl.initialize,
            (
                address(srcBridge),
                address(accessControl),
                ADMIN_ROLE,
                address(destToken)
            )
        );
        address bridgeDestProxy =
            address(new ERC1967Proxy(address(bridgeDestImpl), bridgeDestData));
        destBridge = ThriveBridgeDestination(bridgeDestProxy);

        destToken.setMinter(address(destBridge));
        srcBridge.setDestContract(address(destBridge));

        vm.stopPrank();
    }

    /////////////////////
    // setDestContract //
    /////////////////////

    function test_SetDestContract() public {
        vm.prank(addr1);
        srcBridge.setDestContract(address(destBridge));

        address dest = address(srcBridge.destContract());
        assertEq(dest, address(destBridge));
    }

    function test_SetDestContractFromNotOwner() public {
        vm.startPrank(addr2);
        bytes4 selector =
            bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, addr2));
        srcBridge.setDestContract(address(destBridge));
        vm.stopPrank();
    }

    ////////////////
    // lockTokens //
    ////////////////

    function test_LockTokens() public {
        vm.startPrank(addr1);

        deal(addr1, 10 ether);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge),
            addr1,
            addr1,
            srcBridge.lockNonces(addr1),
            10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectEmit(true, true, false, true);
        emit TokenLocked(
            addr1,
            addr1,
            10 ether,
            vm.getBlockTimestamp(),
            srcBridge.lockNonces(addr1),
            signature
        );

        srcBridge.lockTokens{value: 10 ether}(addr1, 10 ether, signature);

        assertEq(address(addr1).balance, 0);
        assertEq(address(srcBridge).balance, 10 ether);
        assertEq(srcBridge.lockNonces(addr1), 1);
        assertEq(srcBridge.supply(), 10 ether);

        vm.stopPrank();
    }

    function test_LockTokensDifferentReceipt() public {
        vm.startPrank(addr1);

        deal(addr1, 10 ether);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge),
            addr1,
            addr2,
            srcBridge.lockNonces(addr1),
            10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectEmit(true, true, false, true);
        emit TokenLocked(
            addr1,
            addr2,
            10 ether,
            vm.getBlockTimestamp(),
            srcBridge.lockNonces(addr1),
            signature
        );

        srcBridge.lockTokens{value: 10 ether}(addr2, 10 ether, signature);

        assertEq(address(addr1).balance, 0);
        assertEq(address(srcBridge).balance, 10 ether);
        assertEq(srcBridge.lockNonces(addr1), 1);
        assertEq(srcBridge.supply(), 10 ether);

        vm.stopPrank();
    }

    function test_LockTokensNonAdmin() public {
        vm.startPrank(addr2);

        deal(addr2, 10 ether);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge),
            addr2,
            addr2,
            srcBridge.lockNonces(addr2),
            10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey2, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectEmit(true, true, false, true);
        emit TokenLocked(
            addr2,
            addr2,
            10 ether,
            vm.getBlockTimestamp(),
            srcBridge.lockNonces(addr2),
            signature
        );

        srcBridge.lockTokens{value: 10 ether}(addr2, 10 ether, signature);

        assertEq(address(addr2).balance, 0);
        assertEq(address(srcBridge).balance, 10 ether);
        assertEq(srcBridge.lockNonces(addr2), 1);
        assertEq(srcBridge.supply(), 10 ether);

        vm.stopPrank();
    }

    function test_LockTokensWithZeroAmount() public {
        vm.startPrank(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, srcBridge.lockNonces(addr1), 0
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            bytes("ThriveProtocol: amount must be greater than zero")
        );

        srcBridge.lockTokens{value: 0}(addr1, 0, signature);

        vm.stopPrank();
    }

    function test_LockTokensInvalidSignature() public {
        vm.startPrank(addr1);

        deal(addr1, 10 ether);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(destBridge),
            addr1,
            addr1,
            srcBridge.lockNonces(addr1),
            10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(bytes("ThriveProtocol: invalid signature"));

        srcBridge.lockTokens{value: 10 ether}(addr1, 10 ether, signature);

        vm.stopPrank();
    }

    function test_LockTokensNotEnoughFunds() public {
        vm.startPrank(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge),
            addr1,
            addr1,
            srcBridge.lockNonces(addr1),
            10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert();

        srcBridge.lockTokens{value: 10 ether}(addr1, 10 ether, signature);

        vm.stopPrank();
    }

    function test_LockTokensMismatchedAmount() public {
        vm.startPrank(addr1);

        deal(addr1, 10 ether);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge),
            addr1,
            addr1,
            srcBridge.lockNonces(addr1),
            5 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            bytes("ThriveProtocol: amount must match received value")
        );

        srcBridge.lockTokens{value: 7 ether}(addr1, 5 ether, signature);

        vm.stopPrank();
    }

    //////////////////
    // unlockTokens //
    //////////////////

    function test_UnlockTokens() public {
        vm.startPrank(addr1);

        deal(addr1, 10 ether);

        uint256 lockNonce = srcBridge.lockNonces(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectEmit(true, true, false, true);
        emit TokenLocked(
            addr1, addr1, 10 ether, vm.getBlockTimestamp(), lockNonce, signature
        );

        srcBridge.lockTokens{value: 10 ether}(addr1, 10 ether, signature);

        assertEq(address(addr1).balance, 0);
        assertEq(address(srcBridge).balance, 10 ether);
        assertEq(srcBridge.lockNonces(addr1), lockNonce + 1);

        uint256 burnNonce = destBridge.burnNonces(addr2);

        hash = SignatureHelper.hashBridgeRequest(
            address(destBridge), addr2, addr2, burnNonce, 10 ether
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey2, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectEmit(true, true, false, true);
        emit TokenUnlocked(
            addr2, addr2, 10 ether, vm.getBlockTimestamp(), burnNonce, signature
        );

        srcBridge.unlockTokens(addr2, addr2, 10 ether, burnNonce, signature);

        assertEq(address(addr1).balance, 0);
        assertEq(address(addr2).balance, 10 ether);
        assertEq(address(srcBridge).balance, 0 ether);
        assertEq(srcBridge.unlockNonces(addr2, burnNonce), true);
        assertEq(srcBridge.supply(), 0);

        vm.stopPrank();
    }

    function test_UnlockTokensDifferentReceipt() public {
        vm.startPrank(addr1);

        deal(addr1, 10 ether);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge),
            addr1,
            addr1,
            srcBridge.lockNonces(addr1),
            10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        srcBridge.lockTokens{value: 10 ether}(addr1, 10 ether, signature);

        uint256 burnNonce = destBridge.burnNonces(addr2);

        hash = SignatureHelper.hashBridgeRequest(
            address(destBridge), addr2, addr1, burnNonce, 5 ether
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey2, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectEmit(true, true, false, true);
        emit TokenUnlocked(
            addr2, addr1, 5 ether, vm.getBlockTimestamp(), burnNonce, signature
        );

        srcBridge.unlockTokens(addr2, addr1, 5 ether, burnNonce, signature);

        assertEq(address(addr1).balance, 5 ether);
        assertEq(address(addr2).balance, 0 ether);
        assertEq(address(srcBridge).balance, 5 ether);
        assertEq(srcBridge.unlockNonces(addr2, burnNonce), true);
        assertEq(srcBridge.supply(), 5 ether);

        vm.stopPrank();
    }

    function test_UnlockTokensOnlyAdmin() public {
        vm.startPrank(addr1);

        deal(addr1, 10 ether);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge),
            addr1,
            addr1,
            srcBridge.lockNonces(addr1),
            10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        srcBridge.lockTokens{value: 10 ether}(addr1, 10 ether, signature);

        vm.stopPrank();

        vm.startPrank(addr2);

        uint256 burnNonce = destBridge.burnNonces(addr2);

        hash = SignatureHelper.hashBridgeRequest(
            address(destBridge), addr2, addr2, burnNonce, 0
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey2, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectRevert(bytes("ThriveProtocol: must have admin role"));

        srcBridge.unlockTokens(addr2, addr2, 0, burnNonce, signature);

        vm.stopPrank();
    }

    function test_UnlockTokensZeroAmount() public {
        vm.startPrank(addr1);

        deal(addr1, 10 ether);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge),
            addr1,
            addr1,
            srcBridge.lockNonces(addr1),
            10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        srcBridge.lockTokens{value: 10 ether}(addr1, 10 ether, signature);

        uint256 burnNonce = destBridge.burnNonces(addr2);

        hash = SignatureHelper.hashBridgeRequest(
            address(destBridge), addr2, addr2, burnNonce, 0
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey2, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            bytes("ThriveProtocol: amount must be greater than zero")
        );

        srcBridge.unlockTokens(addr2, addr2, 0, burnNonce, signature);

        vm.stopPrank();
    }

    function test_UnlockTokensDoubleSpend() public {
        vm.startPrank(addr1);

        deal(addr1, 10 ether);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge),
            addr1,
            addr1,
            srcBridge.lockNonces(addr1),
            10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        srcBridge.lockTokens{value: 10 ether}(addr1, 10 ether, signature);

        uint256 burnNonce = destBridge.burnNonces(addr2);

        hash = SignatureHelper.hashBridgeRequest(
            address(destBridge), addr2, addr2, burnNonce, 5 ether
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey2, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectEmit(true, true, false, true);
        emit TokenUnlocked(
            addr2, addr2, 5 ether, vm.getBlockTimestamp(), burnNonce, signature
        );

        srcBridge.unlockTokens(addr2, addr2, 5 ether, burnNonce, signature);

        assertEq(address(addr1).balance, 0);
        assertEq(address(addr2).balance, 5 ether);
        assertEq(address(srcBridge).balance, 5 ether);
        assertEq(srcBridge.unlockNonces(addr2, burnNonce), true);

        vm.expectRevert(bytes("ThriveProtocol: request already processed"));
        srcBridge.unlockTokens(addr2, addr2, 5 ether, burnNonce, signature);

        vm.stopPrank();
    }

    function test_UnlockTokensInvalidSignature() public {
        vm.startPrank(addr1);

        deal(addr1, 10 ether);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge),
            addr1,
            addr1,
            srcBridge.lockNonces(addr1),
            10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        srcBridge.lockTokens{value: 10 ether}(addr1, 10 ether, signature);

        uint256 burnNonce = destBridge.burnNonces(addr2);

        hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr2, addr2, burnNonce, 10 ether
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey2, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectRevert(bytes("ThriveProtocol: invalid signature"));

        srcBridge.unlockTokens(addr2, addr2, 10 ether, burnNonce, signature);

        vm.stopPrank();
    }

    ////////////////////////////////
    // setAccessControlEnumerable //
    ////////////////////////////////

    function test_SetAccessControl() public {
        ThriveProtocolAccessControl accessControlImpl =
            new ThriveProtocolAccessControl();
        bytes memory accessControlData =
            abi.encodeCall(accessControlImpl.initialize, ());
        address accessControlProxy = address(
            new ERC1967Proxy(address(accessControlImpl), accessControlData)
        );
        ThriveProtocolAccessControl newAccessControl =
            ThriveProtocolAccessControl(accessControlProxy);

        vm.prank(addr1);
        srcBridge.setAccessControlEnumerable(
            address(newAccessControl), OTHER_ADMIN_ROLE
        );

        address accessAddress = address(srcBridge.accessControlEnumerable());
        bytes32 newRole = srcBridge.role();
        assertEq(accessAddress, address(newAccessControl));
        assertEq(newRole, OTHER_ADMIN_ROLE);
    }

    function test_AccessControlFromNotOwner() public {
        ThriveProtocolAccessControl accessControlImpl =
            new ThriveProtocolAccessControl();
        bytes memory accessControlData =
            abi.encodeCall(accessControlImpl.initialize, ());
        address accessControlProxy = address(
            new ERC1967Proxy(address(accessControlImpl), accessControlData)
        );
        ThriveProtocolAccessControl newAccessControl =
            ThriveProtocolAccessControl(accessControlProxy);

        vm.startPrank(addr2);
        bytes4 selector =
            bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, addr2));
        srcBridge.setAccessControlEnumerable(
            address(newAccessControl), OTHER_ADMIN_ROLE
        );
        vm.stopPrank();
    }
}
