// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ThriveBridgeSourceIERC20} from "../src/ThriveBridgeSourceIERC20.sol";
import {ThriveBridgeDestinationWithCompliance} from
    "../src/ThriveBridgeDestinationWithCompliance.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";
import {ThriveIERC20Wrapper} from "src/ThriveIERC20Wrapper.sol";
import {ThriveComplianceStore} from "src/ThriveComplianceStore.sol";
import {ThriveOraclePriceStore} from "src/ThriveOraclePriceStore.sol";
import {SignatureHelper} from "src/libraries/SignatureHelper.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from
    "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract ThriveBridgeDestinationWithComplianceTest is Test {
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
    ThriveBridgeDestinationWithCompliance public destBridge;
    ThriveProtocolAccessControl public accessControl;
    ThriveIERC20Wrapper public srcToken;
    ThriveIERC20Wrapper public destToken;
    ThriveOraclePriceStore public priceStore;
    ThriveComplianceStore complianceStore;
    string pair = "DDM-USDT";

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

        priceStore = new ThriveOraclePriceStore();
        priceStore.initialize(address(accessControlProxy), ADMIN_ROLE, 18);
        priceStore.setPrice(pair, 1 ether);

        complianceStore = new ThriveComplianceStore();
        complianceStore.initialize(address(accessControlProxy), ADMIN_ROLE);
        complianceStore.setCheckTypeValidityDuration(keccak256("KYC"), 100 days);

        ThriveBridgeSourceIERC20 bridgeSrcImpl = new ThriveBridgeSourceIERC20();
        bytes memory bridgeSrcData = abi.encodeCall(
            bridgeSrcImpl.initialize,
            (address(0), address(accessControl), ADMIN_ROLE, address(srcToken))
        );
        address bridgeSrcProxy =
            address(new ERC1967Proxy(address(bridgeSrcImpl), bridgeSrcData));
        srcBridge = ThriveBridgeSourceIERC20(bridgeSrcProxy);

        ThriveBridgeDestinationWithCompliance bridgeDestImpl =
            new ThriveBridgeDestinationWithCompliance();
        bytes memory bridgeDestData = abi.encodeWithSelector(
            ThriveBridgeDestinationWithCompliance.initialize.selector,
            address(srcBridge),
            address(accessControl),
            ADMIN_ROLE,
            address(destToken),
            pair,
            address(priceStore),
            address(complianceStore)
        );
        address bridgeDestProxy =
            address(new ERC1967Proxy(address(bridgeDestImpl), bridgeDestData));
        destBridge = ThriveBridgeDestinationWithCompliance(bridgeDestProxy);

        destToken.setMinter(address(destBridge));
        srcBridge.setDestContract(address(destBridge));

        destBridge.setComplianceRule(keccak256("KYC"), 100 ether);

        vm.stopPrank();
    }

    ////////////////
    // burnTokens //
    ////////////////

    function test_BurnTokensUnderLimit() public {
        vm.startPrank(addr1);

        uint256 lockNonce = srcBridge.lockNonces(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 100 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        destBridge.mintTokens(addr1, addr1, 100 ether, lockNonce, signature);
        assertEq(destToken.balanceOf(addr1), 100 ether);

        // burn
        destToken.approve(address(destBridge), 100 ether - 1);
        uint256 burnNonce = destBridge.burnNonces(addr1);

        hash = SignatureHelper.hashBridgeRequest(
            address(destBridge), addr1, addr1, burnNonce, 100 ether - 1
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey1, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectEmit(true, true, false, true);
        emit TokenBurned(
            addr1,
            addr1,
            100 ether - 1,
            vm.getBlockTimestamp(),
            burnNonce,
            signature
        );

        destBridge.burnTokens(addr1, 100 ether - 1, signature);

        assertEq(destToken.balanceOf(addr1), 1);
        assertEq(destBridge.burnNonces(addr1), burnNonce + 1);
        assertEq(destBridge.supply(), 1);

        vm.stopPrank();
    }

    function test_BurnTokensComplianceNotPresent() public {
        vm.startPrank(addr1);

        uint256 lockNonce = srcBridge.lockNonces(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 100 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        destBridge.mintTokens(addr1, addr1, 100 ether, lockNonce, signature);
        assertEq(destToken.balanceOf(addr1), 100 ether);

        // burn
        destToken.approve(address(destBridge), 100 ether);
        uint256 burnNonce = destBridge.burnNonces(addr1);

        hash = SignatureHelper.hashBridgeRequest(
            address(destBridge), addr1, addr1, burnNonce, 100 ether
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey1, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectRevert(bytes("Compliance check failed"));

        destBridge.burnTokens(addr1, 100 ether, signature);

        vm.stopPrank();
    }

    function test_BurnTokensComplianceNotPassed() public {
        vm.startPrank(addr1);

        // compliance
        complianceStore.setComplianceCheck(keccak256("KYC"), addr1, false);

        uint256 lockNonce = srcBridge.lockNonces(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 100 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        destBridge.mintTokens(addr1, addr1, 100 ether, lockNonce, signature);
        assertEq(destToken.balanceOf(addr1), 100 ether);

        // burn
        destToken.approve(address(destBridge), 100 ether);
        uint256 burnNonce = destBridge.burnNonces(addr1);

        hash = SignatureHelper.hashBridgeRequest(
            address(destBridge), addr1, addr1, burnNonce, 100 ether
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey1, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectRevert(bytes("Compliance check failed"));

        destBridge.burnTokens(addr1, 100 ether, signature);

        vm.stopPrank();
    }

    function test_BurnTokensCompliancePassed() public {
        vm.startPrank(addr1);

        // compliance
        complianceStore.setComplianceCheck(keccak256("KYC"), addr1, true);

        uint256 lockNonce = srcBridge.lockNonces(addr1);

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(srcBridge), addr1, addr1, lockNonce, 100 ether
        );
        bytes32 ethSignedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privKey1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        destBridge.mintTokens(addr1, addr1, 100 ether, lockNonce, signature);
        assertEq(destToken.balanceOf(addr1), 100 ether);

        // burn
        destToken.approve(address(destBridge), 100 ether);
        uint256 burnNonce = destBridge.burnNonces(addr1);

        hash = SignatureHelper.hashBridgeRequest(
            address(destBridge), addr1, addr1, burnNonce, 100 ether
        );
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (v, r, s) = vm.sign(privKey1, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectEmit(true, true, false, true);
        emit TokenBurned(
            addr1,
            addr1,
            100 ether,
            vm.getBlockTimestamp(),
            burnNonce,
            signature
        );

        destBridge.burnTokens(addr1, 100 ether, signature);

        assertEq(destToken.balanceOf(addr1), 0);
        assertEq(destBridge.burnNonces(addr1), burnNonce + 1);
        assertEq(destBridge.supply(), 0);

        vm.stopPrank();
    }

    ////////////////////////
    // setComplianceStore //
    ////////////////////////

    function test_setComplianceStore() public {
        vm.prank(addr1);
        destBridge.setComplianceStore(address(8));
        assertEq(address(destBridge.complianceStore()), address(8));
    }

    function test_setComplianceStoreFromNotOwner() public {
        vm.startPrank(addr2);
        bytes4 selector =
            bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, addr2));
        destBridge.setComplianceStore(address(8));
        vm.stopPrank();
    }

    ///////////////////
    // setPriceStore //
    ///////////////////

    function test_setPriceStore() public {
        vm.prank(addr1);
        destBridge.setPriceStore(address(8));
        assertEq(address(destBridge.priceStore()), address(8));
    }

    function test_setPriceStoreFromNotOwner() public {
        vm.startPrank(addr2);
        bytes4 selector =
            bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, addr2));
        destBridge.setPriceStore(address(8));
        vm.stopPrank();
    }

    ///////////////////////
    // setComplianceRule //
    ///////////////////////

    function test_setComplianceRule() public {
        bytes32 checkType = keccak256("WALLET_CHECK");
        uint256 count = destBridge.getComplianceRuleCount();

        vm.prank(addr1);
        destBridge.setComplianceRule(checkType, 30);
        assertEq(destBridge.complianceRules(checkType), 30);
        assertEq(destBridge.getComplianceRuleCount(), count + 1);
    }

    function test_setPriceStoreFromNotAdmin() public {
        bytes32 checkType = keccak256("WALLET_CHECK");
        vm.startPrank(addr2);
        vm.expectRevert(bytes("ThriveProtocol: must have admin role"));
        destBridge.setComplianceRule(checkType, 30);
        vm.stopPrank();
    }

    function test_setPriceStoreLimitZero() public {
        bytes32 checkType = keccak256("WALLET_CHECK");
        vm.startPrank(addr1);
        vm.expectRevert(bytes("Limit must be greater than 0"));
        destBridge.setComplianceRule(checkType, 0);
        vm.stopPrank();
    }

    //////////////////////////
    // removeComplianceRule //
    //////////////////////////

    function test_removeComplianceRule() public {
        bytes32 checkType = keccak256("WALLET_CHECK");

        vm.startPrank(addr1);
        destBridge.setComplianceRule(checkType, 30);
        uint256 count = destBridge.getComplianceRuleCount();

        destBridge.removeComplianceRule(checkType);
        assertEq(destBridge.complianceRules(checkType), 0);
        assertEq(destBridge.getComplianceRuleCount(), count - 1);
        vm.stopPrank();
    }

    function test_removeComplianceRuleFromNotAdmin() public {
        bytes32 checkType = keccak256("WALLET_CHECK");
        vm.startPrank(addr2);
        vm.expectRevert(bytes("ThriveProtocol: must have admin role"));
        destBridge.removeComplianceRule(checkType);
        vm.stopPrank();
    }

    function test_removeComplianceRuleNotExisting() public {
        bytes32 checkType = keccak256("WALLET_CHECK");
        vm.startPrank(addr1);
        vm.expectRevert(bytes("Rule does not exist"));
        destBridge.removeComplianceRule(checkType);
        vm.stopPrank();
    }

    ///////////////////////
    // getComplianceRule //
    ///////////////////////

    function test_getComplianceRule() public view {
        (bytes32 checkType, uint256 limit) = destBridge.getComplianceRule(0);
        assertEq(checkType, keccak256("KYC"));
        assertEq(limit, 100 ether);
    }

    function test_getComplianceRuleNotExisting() public {
        vm.expectRevert();
        destBridge.getComplianceRule(5);
    }

    ////////////////////////////
    // getComplianceRuleCount //
    ////////////////////////////

    function test_getComplianceRuleCount() public view {
        uint256 count = destBridge.getComplianceRuleCount();
        assertEq(count, 1);
    }
}
