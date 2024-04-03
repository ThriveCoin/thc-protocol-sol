//SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {ThriveProtocolCommunity} from "src/ThriveProtocolCommunity.sol";
import "test/mock/MockAccessControl.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract ThriveProtocolCommunityTest is Test {
    ThriveProtocolCommunity community;
    MockAccessControl accessControl;
    MockERC20 token1;
    MockERC20 token2;

    address rewardsAdmin;
    address treasuryAdmin;
    address validationsAdmin;
    address foundationAdmin;

    event Transfer(
        address indexed _from,
        address indexed _to,
        address indexed _token,
        uint256 _amount
    );

    function setUp() public {
        rewardsAdmin = address(1);
        treasuryAdmin = address(2);
        validationsAdmin = address(3);
        foundationAdmin = address(4);

        vm.startPrank(address(6));
        accessControl = new MockAccessControl();
        accessControl.grantRole(0x00, address(1));
        vm.stopPrank();

        vm.prank(address(1));
        community = new ThriveProtocolCommunity(
            address(1),
            "test",
            [rewardsAdmin, treasuryAdmin, validationsAdmin, foundationAdmin],
            [uint256(80), 5, 5, 10],
            address(accessControl)
        );

        token1 = new MockERC20("token1", "tkn1");
        token2 = new MockERC20("token2", "tkn2");

        token1.mint(address(1), 1000);
        token2.mint(address(2), 1000);
    }

    /////////////
    // deposit //
    /////////////

    function test_deposit() public {
        vm.startPrank(address(1));
        token1.approve(address(community), 100);
        community.deposit(address(token1), 100);
        vm.stopPrank();

        vm.startPrank(address(2));
        token2.approve(address(community), 1000);
        community.deposit(address(token2), 1000);
        vm.stopPrank();

        uint256 rewardsBalance1 =
            community.balances(rewardsAdmin, address(token1));
        uint256 treasuryBalance1 =
            community.balances(treasuryAdmin, address(token1));
        uint256 validationsBalance1 =
            community.balances(validationsAdmin, address(token1));
        uint256 foundationBalance1 =
            community.balances(foundationAdmin, address(token1));

        uint256 rewardsBalance2 =
            community.balances(rewardsAdmin, address(token2));
        uint256 treasuryBalance2 =
            community.balances(treasuryAdmin, address(token2));
        uint256 validationsBalance2 =
            community.balances(validationsAdmin, address(token2));
        uint256 foundationBalance2 =
            community.balances(foundationAdmin, address(token2));

        assertEq(rewardsBalance1, 80);
        assertEq(treasuryBalance1, 5);
        assertEq(validationsBalance1, 5);
        assertEq(foundationBalance1, 10);

        assertEq(rewardsBalance2, 800);
        assertEq(treasuryBalance2, 50);
        assertEq(validationsBalance2, 50);
        assertEq(foundationBalance2, 100);
    }

    function test_deposit_withDust() public {
        uint amount = 111;
        vm.startPrank(address(1));
        token1.approve(address(community), amount);
        community.deposit(address(token1), amount);
        vm.stopPrank();

        uint256 rewardsBalance1 =
            community.balances(rewardsAdmin, address(token1));
        uint256 treasuryBalance1 =
            community.balances(treasuryAdmin, address(token1));
        uint256 validationsBalance1 =
            community.balances(validationsAdmin, address(token1));
        uint256 foundationBalance1 =
            community.balances(foundationAdmin, address(token1));

        assertEq(treasuryBalance1, 5);
        assertEq(validationsBalance1, 5);
        assertEq(foundationBalance1, 11);
        assertEq(rewardsBalance1, 90);
        assertEq(
            rewardsBalance1 + treasuryBalance1 + validationsBalance1
                + foundationBalance1,
            amount
        );
    }

    function testFailed_deposit_withoutAllowance() public {
        vm.prank(address(1));
        community.deposit(address(token1), 100);
    }

    function test_deposit_ZeroAmount() public {
        vm.prank(address(1));
        community.deposit(address(token1), 0);

        assertEq(token1.balanceOf(address(community)), 0);
        assertEq(community.balances(rewardsAdmin, address(token1)), 0);
        assertEq(community.balances(treasuryAdmin, address(token1)), 0);
        assertEq(community.balances(validationsAdmin, address(token1)), 0);
        assertEq(community.balances(foundationAdmin, address(token1)), 0);
    }

    /////////////////////////
    // validations deposit //
    /////////////////////////

    function test_validationsDeposit() public {
        vm.startPrank(address(1));
        token1.approve(address(community), 100);
        community.validationsDeposit(address(token1), 100);
        vm.stopPrank();

        vm.startPrank(address(2));
        token2.approve(address(community), 1000);
        community.validationsDeposit(address(token2), 1000);
        vm.stopPrank();

        assertEq(community.balances(validationsAdmin, address(token1)), 100);
        assertEq(community.balances(validationsAdmin, address(token2)), 1000);
    }

    function testFaild_validationsDeposit_withoutAllowance() public {
        vm.prank(address(1));
        community.validationsDeposit(address(token1), 100);
    }

    //////////////
    // withdraw //
    //////////////

    function test_withdraw() public {
        vm.startPrank(address(1));
        token1.approve(address(community), 100);
        community.deposit(address(token1), 100);
        vm.stopPrank();

        vm.startPrank(address(2));
        token2.approve(address(community), 1000);
        community.deposit(address(token2), 1000);
        vm.stopPrank();

        uint256 validationsBalance = token1.balanceOf(address(validationsAdmin));
        uint256 foundationBalance = token2.balanceOf(address(foundationAdmin));

        vm.prank(validationsAdmin);
        vm.expectEmit(true, true, true, true);
        emit Transfer(
            address(community), address(validationsAdmin), address(token1), 4
        );
        community.withdraw(address(token1), 4);

        vm.prank(foundationAdmin);
        vm.expectEmit(true, true, true, true);
        emit Transfer(
            address(community), address(foundationAdmin), address(token2), 100
        );
        community.withdraw(address(token2), 100);

        assertEq(
            community.balances(address(validationsAdmin), address(token1)), 1
        );
        assertEq(
            community.balances(address(foundationAdmin), address(token2)), 0
        );

        assertEq(
            token1.balanceOf(address(validationsAdmin)), validationsBalance + 4
        );
        assertEq(
            token2.balanceOf(address(foundationAdmin)), foundationBalance + 100
        );
    }

    function test_withdraw_withInsufficientBalance() public {
        vm.startPrank(address(1));
        token1.approve(address(community), 100);
        community.deposit(address(token1), 100);
        vm.stopPrank();

        vm.startPrank(address(rewardsAdmin));
        vm.expectRevert("Insufficient balance");
        community.withdraw(address(token1), 90);
        vm.expectRevert("Insufficient balance");
        community.withdraw(address(token2), 1);
    }

    function test_withdraw_fromNotAdminAccount() public {
        vm.startPrank(address(1));
        token1.approve(address(community), 100);
        community.deposit(address(token1), 100);
        vm.stopPrank();

        vm.startPrank(address(5));
        vm.expectRevert("Insufficient balance");
        community.withdraw(address(token1), 1);
        vm.expectRevert("Insufficient balance");
        community.withdraw(address(token2), 1);
    }

    //////////////
    // transfer //
    //////////////

    function test_transfer() public {
        vm.startPrank(address(1));
        token1.approve(address(community), 100);
        community.deposit(address(token1), 100);
        vm.stopPrank();

        vm.startPrank(address(2));
        token2.approve(address(community), 1000);
        community.deposit(address(token2), 1000);
        vm.stopPrank();

        uint256 token1Balance = token1.balanceOf(address(5));
        uint256 token2Balance = token2.balanceOf(address(5));

        vm.prank(validationsAdmin);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(community), address(5), address(token1), 4);
        community.transfer(address(5), address(token1), 4);

        vm.prank(foundationAdmin);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(community), address(5), address(token2), 100);
        community.transfer(address(5), address(token2), 100);

        assertEq(
            community.balances(address(validationsAdmin), address(token1)), 1
        );
        assertEq(
            community.balances(address(foundationAdmin), address(token2)), 0
        );

        assertEq(token1.balanceOf(address(5)), token1Balance + 4);
        assertEq(token2.balanceOf(address(5)), token2Balance + 100);
    }

    function test_transfer_withInsufficientBalance() public {
        vm.startPrank(address(1));
        token1.approve(address(community), 100);
        community.deposit(address(token1), 100);
        vm.stopPrank();

        vm.startPrank(address(rewardsAdmin));
        vm.expectRevert("Insufficient balance");
        community.transfer(address(5), address(token1), 90);
        vm.expectRevert("Insufficient balance");
        community.transfer(address(5), address(token2), 1);
    }

    function test_transfer_fromNotAdminAccount() public {
        vm.startPrank(address(1));
        token1.approve(address(community), 100);
        community.deposit(address(token1), 100);
        vm.stopPrank();

        vm.startPrank(address(5));
        vm.expectRevert("Insufficient balance");
        community.transfer(address(6), address(token1), 1);
        vm.expectRevert("Insufficient balance");
        community.transfer(address(6), address(token2), 1);
    }

    /////////////
    // setters //
    /////////////

    function test_setAdmins() public {
        vm.prank(address(1));
        community.setAdmins(address(2), address(3), address(4), address(5));

        assertEq(community.getRewardsAdmin(), address(2));
        assertEq(community.getTreasuryAdmin(), address(3));
        assertEq(community.getValidationsAdmin(), address(4));
        assertEq(community.getFoundationAdmin(), address(5));
    }

    function test_setAdmins_withoutRole() public {
        vm.prank(address(2));
        vm.expectRevert("ThriveProtocolCommunity: must have admin role");
        community.setAdmins(address(2), address(3), address(4), address(5));

        vm.prank(address(1));
        accessControl.grantRole(0x00, address(2));
        vm.prank(address(2));
        community.setAdmins(address(2), address(3), address(4), address(5));
        assertEq(community.getRewardsAdmin(), address(2));
    }

    function test_setPecents() public {
        vm.prank(address(1));
        community.setPercentage(90, 1, 1, 8);

        assertEq(community.getRewardsPercentage(), 90);
        assertEq(community.getTreasuryPercentage(), 1);
        assertEq(community.getValidationsPercentage(), 1);
        assertEq(community.getFoundationPercentage(), 8);
    }

    function test_setPercents_withoutRole() public {
        vm.prank(address(2));
        vm.expectRevert("ThriveProtocolCommunity: must have admin role");
        community.setPercentage(90, 1, 1, 8);

        vm.prank(address(1));
        accessControl.grantRole(0x00, address(2));
        vm.prank(address(2));
        community.setPercentage(90, 1, 1, 8);
        assertEq(community.getRewardsPercentage(), 90);
    }

    function test_setAccessControl() public {
        MockAccessControl newAccessControl = new MockAccessControl();

        vm.prank(address(1));
        community.setAccessControlEnumerable(address(newAccessControl));

        address accessAddress = address(community.accessControlEnumerable());
        assertEq(accessAddress, address(newAccessControl));
    }

    function test_sAccessControl_fromNotOwner() public {
        MockAccessControl newAccessControl = new MockAccessControl();

        vm.startPrank(address(2));
        bytes4 selector =
            bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, address(2)));
        community.setAccessControlEnumerable(address(newAccessControl));
    }

    /////////////
    // getters //
    /////////////

    function test_getName() public view {
        assertEq(community.getName(), "test");
    }

    function test_getRewardsAdmin() public view {
        assertEq(community.getRewardsAdmin(), rewardsAdmin);
    }

    function test_getTreasuryAdmin() public view {
        assertEq(community.getTreasuryAdmin(), treasuryAdmin);
    }

    function test_getValidationsAdmin() public view {
        assertEq(community.getValidationsAdmin(), validationsAdmin);
    }

    function test_getFoundationAdmin() public view {
        assertEq(community.getFoundationAdmin(), foundationAdmin);
    }

    function test_getRewardsPercent() public view {
        assertEq(community.getRewardsPercentage(), 80);
    }

    function test_getTreasuryPercent() public view {
        assertEq(community.getTreasuryPercentage(), 5);
    }

    function test_getValidationsPercent() public view {
        assertEq(community.getValidationsPercentage(), 5);
    }

    function test_getFoundationPercent() public view {
        assertEq(community.getFoundationPercentage(), 10);
    }
}