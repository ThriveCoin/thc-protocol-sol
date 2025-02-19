// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";
import {ThriveOraclePriceStore} from "src/ThriveOraclePriceStore.sol";

contract ThriveOraclePriceStoreTest is Test {
    ThriveOraclePriceStore public priceStore;
    ThriveProtocolAccessControl public accessControl;

    address owner = address(1);
    address admin = address(2);
    address user = address(3);
    bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    function setUp() public {
        vm.startPrank(owner);
        ThriveProtocolAccessControl accessControlImpl =
            new ThriveProtocolAccessControl();
        bytes memory accessControlData =
            abi.encodeCall(accessControlImpl.initialize, ());
        address accessControlProxy = address(
            new ERC1967Proxy(address(accessControlImpl), accessControlData)
        );
        accessControl = ThriveProtocolAccessControl(accessControlProxy);
        accessControl.grantRole(ADMIN_ROLE, address(1));


        priceStore = new ThriveOraclePriceStore();
        priceStore.initialize(address(accessControlProxy), ADMIN_ROLE);
        vm.stopPrank();
    }

    function test_initialization() public view {
        assertEq(priceStore.role(), ADMIN_ROLE);
    }

    function test_setPrice_asAdmin() public {
        vm.prank(owner);
        priceStore.setPrice("ETH/USD", 3000);
        (uint256 price, uint256 updatedAt, address updatedBy) =
            priceStore.getPrice("ETH/USD");

        assertEq(price, 3000);
        assertGt(updatedAt, 0);
        assertEq(updatedBy, owner);
    }

    function test_setPrice_asNonAdmin() public {
        vm.prank(user);
        vm.expectRevert();
        priceStore.setPrice("ETH/USD", 3200);
    }

    function test_getPrice_returnsCorrectValues() public {
        vm.prank(owner);
        priceStore.setPrice("BTC/USD", 45000);
        (uint256 price, uint256 updatedAt, address updatedBy) =
            priceStore.getPrice("BTC/USD");

        assertEq(price, 45000);
        assertGt(updatedAt, 0);
        assertEq(updatedBy, owner);
    }

    function test_setAccessControlEnumerable() public {
        vm.prank(owner);
        priceStore.setAccessControlEnumerable(
            address(this), keccak256("NEW_ROLE")
        );
        assertEq(priceStore.role(), keccak256("NEW_ROLE"));
    }
}
