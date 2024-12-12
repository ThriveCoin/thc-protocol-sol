// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ThriveBridgeSourceIERC20} from "../src/ThriveBridgeSourceIERC20.sol";
import {ThriveBridgeDestination} from "../src/ThriveBridgeDestination.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";
import {ThriveIERC20Wrapper} from "src/ThriveIERC20Wrapper.sol";
import {SignatureHelper} from "src/libraries/SignatureHelper.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from
    "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract ThriveBridgeDestinationTest is Test {
    event TokenMinted(
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        uint256 timestamp,
        uint256 nonce,
        bytes signature
    );

    event TokenBurned(
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        uint256 timestamp,
        uint256 nonce,
        bytes signature
    );

    bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 OTHER_ADMIN_ROLE = keccak256("OTHER_ADMIN_ROLE");

    ThriveBridgeSourceIERC20 public srcBridge;
    ThriveBridgeDestination public destBridge;
    ThriveProtocolAccessControl public accessControl;
    ThriveIERC20Wrapper public srcToken;
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

        srcToken = new ThriveIERC20Wrapper("SDUMMY", "SDM", 18);
        destToken = new ThriveIERC20Wrapper("DDUMMY", "DDM", 18);

        ThriveBridgeSourceIERC20 bridgeSrcImpl = new ThriveBridgeSourceIERC20();
        bytes memory bridgeSrcData = abi.encodeCall(
            bridgeSrcImpl.initialize,
            (address(0), address(accessControl), ADMIN_ROLE, address(srcToken))
        );
        address bridgeSrcProxy =
            address(new ERC1967Proxy(address(bridgeSrcImpl), bridgeSrcData));
        srcBridge = ThriveBridgeSourceIERC20(bridgeSrcProxy);

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

    function test_SetSrcContract() public {
        vm.prank(addr1);
        destBridge.setSrcContract(address(srcBridge));

        address src = address(destBridge.srcContract());
        assertEq(src, address(srcBridge));
    }

    function test_SetDestContractFromNotOwner() public {
        vm.startPrank(addr2);
        bytes4 selector =
            bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, addr2));
        destBridge.setSrcContract(address(srcBridge));
        vm.stopPrank();
    }

    ////////////////
    // mintTokens //
    ////////////////

    function test_MintTokens() public {
        vm.startPrank(addr1);

        srcToken.mint(addr1, 10 ether);
        srcToken.approve(address(srcBridge), 10 ether);

        uint256 lockNonce = srcBridge.lockNonces(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        srcBridge.lockTokens(addr1, 10 ether, signature);

        assertEq(srcToken.balanceOf(addr1), 0);
        assertEq(srcToken.balanceOf(address(srcBridge)), 10 ether);
        assertEq(srcBridge.lockNonces(addr1), lockNonce + 1);
        assertEq(srcBridge.supply(), 10 ether);

        // bridging

        vm.expectEmit(true, true, false, true);
        emit TokenMinted(
            addr1, addr1, 10 ether, vm.getBlockTimestamp(), lockNonce, signature
        );

        destBridge.mintTokens(addr1, addr1, 10 ether, lockNonce, signature);

        assertEq(destToken.balanceOf(addr1), 10 ether);
        assertEq(srcToken.balanceOf(address(srcBridge)), 10 ether);
        assertEq(destToken.balanceOf(address(destBridge)), 0);
        assertEq(destBridge.mintNonces(addr1, lockNonce), true);
        assertEq(srcBridge.supply(), 10 ether);
        assertEq(destBridge.supply(), 10 ether);

        vm.stopPrank();
    }

    function test_MintTokensDifferentReceipt() public {
        vm.startPrank(addr1);

        srcToken.mint(addr1, 10 ether);
        srcToken.approve(address(srcBridge), 10 ether);

        uint256 lockNonce = srcBridge.lockNonces(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr2, lockNonce, 10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        srcBridge.lockTokens(addr2, 10 ether, signature);

        assertEq(srcToken.balanceOf(addr1), 0);
        assertEq(srcToken.balanceOf(address(srcBridge)), 10 ether);
        assertEq(srcBridge.lockNonces(addr1), lockNonce + 1);
        assertEq(srcBridge.supply(), 10 ether);

        // bridging

        vm.expectEmit(true, true, false, true);
        emit TokenMinted(
            addr1, addr2, 10 ether, vm.getBlockTimestamp(), lockNonce, signature
        );

        destBridge.mintTokens(addr1, addr2, 10 ether, lockNonce, signature);

        assertEq(destToken.balanceOf(addr1), 0);
        assertEq(destToken.balanceOf(addr2), 10 ether);
        assertEq(srcToken.balanceOf(address(srcBridge)), 10 ether);
        assertEq(destToken.balanceOf(address(destBridge)), 0);
        assertEq(destBridge.mintNonces(addr1, lockNonce), true);
        assertEq(srcBridge.supply(), 10 ether);
        assertEq(destBridge.supply(), 10 ether);

        vm.stopPrank();
    }

    function test_MintTokensDifferentSender() public {
        vm.prank(addr1);
        srcToken.mint(addr2, 10 ether);

        vm.startPrank(addr2);
        srcToken.approve(address(srcBridge), 10 ether);

        uint256 lockNonce = srcBridge.lockNonces(addr2);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr2, addr2, lockNonce, 10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey2, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        srcBridge.lockTokens(addr2, 10 ether, signature);

        assertEq(srcToken.balanceOf(addr1), 0);
        assertEq(srcToken.balanceOf(address(srcBridge)), 10 ether);
        assertEq(srcBridge.lockNonces(addr2), lockNonce + 1);
        assertEq(srcBridge.supply(), 10 ether);
        vm.stopPrank();

        // bridging
        vm.startPrank(addr1);

        vm.expectEmit(true, true, false, true);
        emit TokenMinted(
            addr2, addr2, 10 ether, vm.getBlockTimestamp(), lockNonce, signature
        );

        destBridge.mintTokens(addr2, addr2, 10 ether, lockNonce, signature);

        assertEq(destToken.balanceOf(addr1), 0);
        assertEq(destToken.balanceOf(addr2), 10 ether);
        assertEq(srcToken.balanceOf(address(srcBridge)), 10 ether);
        assertEq(destToken.balanceOf(address(destBridge)), 0);
        assertEq(destBridge.mintNonces(addr2, lockNonce), true);
        assertEq(srcBridge.supply(), 10 ether);
        assertEq(destBridge.supply(), 10 ether);

        vm.stopPrank();
    }

    function test_MintTokensZeroAmount() public {
        vm.startPrank(addr1);

        srcToken.mint(addr1, 10 ether);
        srcToken.approve(address(srcBridge), 10 ether);

        uint256 lockNonce = srcBridge.lockNonces(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        srcBridge.lockTokens(addr1, 10 ether, signature);

        assertEq(srcToken.balanceOf(addr1), 0);
        assertEq(srcToken.balanceOf(address(srcBridge)), 10 ether);
        assertEq(srcBridge.lockNonces(addr1), lockNonce + 1);
        assertEq(srcBridge.supply(), 10 ether);

        // bridging

        hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 0 ether
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey1, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            bytes("ThriveProtocol: amount must be greater than zero")
        );

        destBridge.mintTokens(addr1, addr1, 0, lockNonce, signature);

        vm.stopPrank();
    }

    function test_MintTokensInvalidSignature() public {
        vm.startPrank(addr1);

        srcToken.mint(addr1, 10 ether);
        srcToken.approve(address(srcBridge), 10 ether);

        uint256 lockNonce = srcBridge.lockNonces(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        srcBridge.lockTokens(addr1, 10 ether, signature);

        assertEq(srcToken.balanceOf(addr1), 0);
        assertEq(srcToken.balanceOf(address(srcBridge)), 10 ether);
        assertEq(srcBridge.lockNonces(addr1), lockNonce + 1);
        assertEq(srcBridge.supply(), 10 ether);

        // bridging

        hash = SignatureHelper.hashBridgeRequest(
            address(destBridge), addr1, addr1, lockNonce, 10 ether
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey1, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectRevert(bytes("ThriveProtocol: invalid signature"));

        destBridge.mintTokens(addr1, addr1, 10 ether, lockNonce, signature);

        vm.stopPrank();
    }

    function test_MintTokensNonMinter() public {
        vm.startPrank(addr1);

        srcToken.mint(addr1, 10 ether);
        srcToken.approve(address(srcBridge), 10 ether);

        uint256 lockNonce = srcBridge.lockNonces(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        srcBridge.lockTokens(addr1, 10 ether, signature);

        assertEq(srcToken.balanceOf(addr1), 0);
        assertEq(srcToken.balanceOf(address(srcBridge)), 10 ether);
        assertEq(srcBridge.lockNonces(addr1), lockNonce + 1);
        assertEq(srcBridge.supply(), 10 ether);

        // bridging
        destToken.setMinter(addr1);

        hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 10 ether
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey1, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectRevert(bytes("ThriveProtocol: must be minter"));

        destBridge.mintTokens(addr1, addr1, 10 ether, lockNonce, signature);

        vm.stopPrank();
    }

    function test_MintTokensOnlyAdmin() public {
        vm.startPrank(addr1);

        srcToken.mint(addr1, 10 ether);
        srcToken.approve(address(srcBridge), 10 ether);

        uint256 lockNonce = srcBridge.lockNonces(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        srcBridge.lockTokens(addr1, 10 ether, signature);

        assertEq(srcToken.balanceOf(addr1), 0);
        assertEq(srcToken.balanceOf(address(srcBridge)), 10 ether);
        assertEq(srcBridge.lockNonces(addr1), lockNonce + 1);
        assertEq(srcBridge.supply(), 10 ether);
        vm.stopPrank();

        // bridging
        vm.startPrank(addr2);

        hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 10 ether
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey1, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectRevert(bytes("ThriveProtocol: must have admin role"));

        destBridge.mintTokens(addr1, addr1, 10 ether, lockNonce, signature);

        vm.stopPrank();
    }

    ////////////////
    // burnTokens //
    ////////////////

    function test_BurnTokens() public {
        vm.startPrank(addr1);

        uint256 lockNonce = srcBridge.lockNonces(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        destBridge.mintTokens(addr1, addr1, 10 ether, lockNonce, signature);
        assertEq(destToken.balanceOf(addr1), 10 ether);

        // burn
        destToken.approve(address(destBridge), 5 ether);
        uint256 burnNonce = destBridge.burnNonces(addr1);

        hash = SignatureHelper.hashBridgeRequest(
            address(destBridge), addr1, addr1, burnNonce, 5 ether
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey1, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectEmit(true, true, false, true);
        emit TokenBurned(
            addr1, addr1, 5 ether, vm.getBlockTimestamp(), burnNonce, signature
        );

        destBridge.burnTokens(addr1, 5 ether, signature);

        assertEq(destToken.balanceOf(addr1), 5 ether);
        assertEq(destBridge.burnNonces(addr1), burnNonce + 1);
        assertEq(destBridge.supply(), 5 ether);

        vm.stopPrank();
    }

    function test_BurnTokensDifferentReceipt() public {
        vm.startPrank(addr1);

        uint256 lockNonce = srcBridge.lockNonces(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        destBridge.mintTokens(addr1, addr1, 10 ether, lockNonce, signature);
        assertEq(destToken.balanceOf(addr1), 10 ether);

        // burn
        destToken.approve(address(destBridge), 10 ether);
        uint256 burnNonce = destBridge.burnNonces(addr1);

        hash = SignatureHelper.hashBridgeRequest(
            address(destBridge), addr1, addr2, burnNonce, 10 ether
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey1, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectEmit(true, true, false, true);
        emit TokenBurned(
            addr1, addr2, 10 ether, vm.getBlockTimestamp(), burnNonce, signature
        );

        destBridge.burnTokens(addr2, 10 ether, signature);

        assertEq(destToken.balanceOf(addr1), 0);
        assertEq(destBridge.burnNonces(addr1), burnNonce + 1);
        assertEq(destBridge.supply(), 0);

        vm.stopPrank();
    }

    function test_BurnTokensNonAdmin() public {
        vm.startPrank(addr1);

        uint256 lockNonce = srcBridge.lockNonces(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr2, lockNonce, 10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        destBridge.mintTokens(addr1, addr2, 10 ether, lockNonce, signature);
        assertEq(destToken.balanceOf(addr2), 10 ether);

        vm.stopPrank();

        // burn
        vm.startPrank(addr2);

        destToken.approve(address(destBridge), 5 ether);
        uint256 burnNonce = destBridge.burnNonces(addr2);

        hash = SignatureHelper.hashBridgeRequest(
            address(destBridge), addr2, addr2, burnNonce, 5 ether
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey2, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectEmit(true, true, false, true);
        emit TokenBurned(
            addr2, addr2, 5 ether, vm.getBlockTimestamp(), burnNonce, signature
        );

        destBridge.burnTokens(addr2, 5 ether, signature);

        assertEq(destToken.balanceOf(addr2), 5 ether);
        assertEq(destBridge.burnNonces(addr2), burnNonce + 1);
        assertEq(destBridge.supply(), 5 ether);

        vm.stopPrank();
    }

    function test_BurnTokensZeroAmount() public {
        vm.startPrank(addr1);

        uint256 lockNonce = srcBridge.lockNonces(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        destBridge.mintTokens(addr1, addr1, 10 ether, lockNonce, signature);
        assertEq(destToken.balanceOf(addr1), 10 ether);

        // burn
        destToken.approve(address(destBridge), 5 ether);
        uint256 burnNonce = destBridge.burnNonces(addr1);

        hash = SignatureHelper.hashBridgeRequest(
            address(destBridge), addr1, addr1, burnNonce, 0
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey1, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            bytes("ThriveProtocol: amount must be greater than zero")
        );

        destBridge.burnTokens(addr1, 0, signature);

        vm.stopPrank();
    }

    function test_BurnTokensInvalidSignature() public {
        vm.startPrank(addr1);

        uint256 lockNonce = srcBridge.lockNonces(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        destBridge.mintTokens(addr1, addr1, 10 ether, lockNonce, signature);
        assertEq(destToken.balanceOf(addr1), 10 ether);

        // burn
        destToken.approve(address(destBridge), 5 ether);
        uint256 burnNonce = destBridge.burnNonces(addr1);

        hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, burnNonce, 5 ether
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey1, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectRevert(bytes("ThriveProtocol: invalid signature"));

        destBridge.burnTokens(addr1, 5 ether, signature);

        vm.stopPrank();
    }

    function test_BurnTokensNotEnoughFunds() public {
        vm.startPrank(addr1);

        uint256 lockNonce = srcBridge.lockNonces(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        destBridge.mintTokens(addr1, addr1, 10 ether, lockNonce, signature);
        assertEq(destToken.balanceOf(addr1), 10 ether);

        // burn
        destToken.approve(address(destBridge), 15 ether);
        uint256 burnNonce = destBridge.burnNonces(addr1);

        hash = SignatureHelper.hashBridgeRequest(
            address(destBridge), addr1, addr1, burnNonce, 15 ether
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey1, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectRevert();

        destBridge.burnTokens(addr1, 15 ether, signature);

        vm.stopPrank();
    }

    function test_BurnTokensNotApproved() public {
        vm.startPrank(addr1);

        uint256 lockNonce = srcBridge.lockNonces(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 10 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        destBridge.mintTokens(addr1, addr1, 10 ether, lockNonce, signature);
        assertEq(destToken.balanceOf(addr1), 10 ether);

        // burn
        uint256 burnNonce = destBridge.burnNonces(addr1);

        hash = SignatureHelper.hashBridgeRequest(
            address(destBridge), addr1, addr1, burnNonce, 5 ether
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey1, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        bytes4 selector = bytes4(
            keccak256("ERC20InsufficientAllowance(address,uint256,uint256)")
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                selector, address(destBridge), 0 ether, 5 ether
            )
        );

        destBridge.burnTokens(addr1, 5 ether, signature);

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
