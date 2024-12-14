// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveIERC20Wrapper} from "src/ThriveIERC20Wrapper.sol";

contract ThriveIERC20WrapperTest is Test {
    ThriveIERC20Wrapper token;

    address owner = address(1);
    address minter = address(2);
    address user = address(3);

    function setUp() public {
        vm.startPrank(owner);
        token = new ThriveIERC20Wrapper("Thrive Token", "THRIVE", 18);
        vm.stopPrank();
    }

    function test_initialization() public view {
        assertEq(token.name(), "Thrive Token");
        assertEq(token.symbol(), "THRIVE");
        assertEq(token.decimals(), 18);
        assertEq(token.owner(), owner);
        assertEq(token.minter(), owner);
    }

    function test_setMinterAsOwner() public {
        vm.startPrank(owner);
        token.setMinter(minter);
        assertEq(token.minter(), minter);
        vm.stopPrank();
    }

    function test_setMinterAsNonOwner() public {
        vm.prank(user);
        bytes4 selector =
            bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, user));
        token.setMinter(minter);
    }

    function test_mintAsMinter() public {
        vm.startPrank(owner);
        token.setMinter(minter);
        vm.stopPrank();

        vm.startPrank(minter);
        token.mint(user, 1000 ether);
        assertEq(token.balanceOf(user), 1000 ether);
        vm.stopPrank();
    }

    function test_mintAsNonMinter() public {
        vm.prank(user);
        vm.expectRevert("ThriveProtocol: must be minter");
        token.mint(user, 1000 ether);
    }

    function test_burnAsUser() public {
        vm.startPrank(owner);
        token.mint(user, 1000 ether);
        vm.stopPrank();

        vm.startPrank(user);
        token.burn(500 ether);
        assertEq(token.balanceOf(user), 500 ether);
        vm.stopPrank();
    }

    function test_burnMoreThanBalance() public {
        vm.startPrank(owner);
        token.mint(user, 1000 ether);
        vm.stopPrank();

        vm.startPrank(user);
        bytes4 selector = bytes4(
            keccak256("ERC20InsufficientBalance(address,uint256,uint256)")
        );
        vm.expectRevert(
            abi.encodeWithSelector(selector, user, 1000 ether, 1500 ether)
        );
        token.burn(1500 ether);
        vm.stopPrank();
    }

    function test_burnFrom() public {
        vm.startPrank(owner);
        token.mint(user, 1000 ether);
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(owner, 500 ether);
        vm.stopPrank();

        vm.startPrank(owner);
        token.burnFrom(user, 500 ether);
        assertEq(token.balanceOf(user), 500 ether);
        assertEq(token.allowance(user, owner), 0);
        vm.stopPrank();
    }

    function test_burnFromWithoutApproval() public {
        vm.startPrank(owner);
        token.mint(user, 1000 ether);
        vm.stopPrank();

        vm.prank(owner);
        bytes4 selector = bytes4(
            keccak256("ERC20InsufficientAllowance(address,uint256,uint256)")
        );
        vm.expectRevert(abi.encodeWithSelector(selector, owner, 0, 500 ether));
        token.burnFrom(user, 500 ether);
    }
}
