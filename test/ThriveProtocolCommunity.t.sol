//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {ThriveProtocolCommunity} from "src/ThriveProtocolCommunity.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";

contract ThriveProtocolCommunityTest is Test {
    bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 OTHER_ADMIN_ROLE = keccak256("OTHER_ADMIN_ROLE");

    ThriveProtocolCommunity community;
    ThriveProtocolAccessControl accessControl;
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
        ThriveProtocolAccessControl accessControlImpl =
            new ThriveProtocolAccessControl();
        bytes memory accessControlData =
            abi.encodeCall(accessControlImpl.initialize, ());
        address accessControlProxy = address(
            new ERC1967Proxy(address(accessControlImpl), accessControlData)
        );
        accessControl = ThriveProtocolAccessControl(accessControlProxy);
        accessControl.grantRole(ADMIN_ROLE, address(1));
        vm.stopPrank();

        vm.startPrank(address(1));
        ThriveProtocolCommunity communityImpl = new ThriveProtocolCommunity();
        bytes memory communityData = abi.encodeCall(
            communityImpl.initialize,
            (
                "test",
                [rewardsAdmin, treasuryAdmin, validationsAdmin, foundationAdmin],
                [uint256(80), 5, 5, 10],
                address(accessControl),
                ADMIN_ROLE
            )
        );
        address communityProxy =
            address(new ERC1967Proxy(address(communityImpl), communityData));
        community = ThriveProtocolCommunity(communityProxy);
        vm.stopPrank();

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
        uint256 amount = 100;
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

        assertEq(rewardsBalance1, 80);
        assertEq(treasuryBalance1, 5);
        assertEq(validationsBalance1, 5);
        assertEq(foundationBalance1, 10);

        amount = 111;
        vm.startPrank(address(1));
        token1.approve(address(community), amount);
        community.deposit(address(token1), amount);
        vm.stopPrank();

        uint256 rewardsBalance2 =
            community.balances(rewardsAdmin, address(token1));
        uint256 treasuryBalance2 =
            community.balances(treasuryAdmin, address(token1));
        uint256 validationsBalance2 =
            community.balances(validationsAdmin, address(token1));
        uint256 foundationBalance2 =
            community.balances(foundationAdmin, address(token1));

        assertEq(treasuryBalance2, 10);
        assertEq(validationsBalance2, 10);
        assertEq(foundationBalance2, 21);
        assertEq(rewardsBalance2, 170);
    }

    function test_deposit_withoutAllowance() public {
        vm.startPrank(address(1));
        bytes4 selector = bytes4(
            keccak256("ERC20InsufficientAllowance(address,uint256,uint256)")
        );
        vm.expectRevert(
            abi.encodeWithSelector(selector, address(community), 0, 100)
        );
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

    function test_validationsDeposit_withoutAllowance() public {
        vm.startPrank(address(1));
        bytes4 selector = bytes4(
            keccak256("ERC20InsufficientAllowance(address,uint256,uint256)")
        );
        vm.expectRevert(
            abi.encodeWithSelector(selector, address(community), 0, 100)
        );
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

    function test_setRewardsAdmin() public {
        vm.prank(address(1));
        community.setRewardsAdmin(address(2));
        assertEq(community.rewardsAdmin(), address(2));
    }

    function test_setTreasuryAdmin() public {
        vm.prank(address(1));
        community.setTreasuryAdmin(address(3));
        assertEq(community.treasuryAdmin(), address(3));
    }

    function test_setValidationsAdmin() public {
        vm.prank(address(1));
        community.setValidationsAdmin(address(4));
        assertEq(community.validationsAdmin(), address(4));
    }

    function test_setFoundationAdmin() public {
        vm.prank(address(1));
        community.setFoundationAdmin(address(5));
        assertEq(community.foundationAdmin(), address(5));
    }

    function test_setRewardsAdmin_withoutRole() public {
        vm.prank(address(2));
        vm.expectRevert("ThriveProtocol: must have admin role");
        community.setRewardsAdmin(address(2));

        vm.prank(address(6));
        accessControl.grantRole(ADMIN_ROLE, address(2));
        vm.prank(address(2));
        community.setRewardsAdmin(address(2));
        assertEq(community.rewardsAdmin(), address(2));
    }

    function test_setTreasuryAdmin_withoutRole() public {
        vm.prank(address(2));
        vm.expectRevert("ThriveProtocol: must have admin role");
        community.setTreasuryAdmin(address(3));

        vm.prank(address(6));
        accessControl.grantRole(ADMIN_ROLE, address(2));
        vm.prank(address(2));
        community.setTreasuryAdmin(address(3));
        assertEq(community.treasuryAdmin(), address(3));
    }

    function test_setValidationsAdmin_withoutRole() public {
        vm.prank(address(2));
        vm.expectRevert("ThriveProtocol: must have admin role");
        community.setValidationsAdmin(address(4));

        vm.prank(address(6));
        accessControl.grantRole(ADMIN_ROLE, address(2));
        vm.prank(address(2));
        community.setValidationsAdmin(address(4));
        assertEq(community.validationsAdmin(), address(4));
    }

    function test_setFoundationAdmin_withoutRole() public {
        vm.prank(address(2));
        vm.expectRevert("ThriveProtocol: must have admin role");
        community.setFoundationAdmin(address(5));

        vm.prank(address(6));
        accessControl.grantRole(ADMIN_ROLE, address(2));
        vm.prank(address(2));
        community.setFoundationAdmin(address(5));
        assertEq(community.foundationAdmin(), address(5));
    }

    function test_setPecents() public {
        vm.prank(address(1));
        community.setPercentage(90, 1, 1, 8);

        assertEq(community.rewardsPercentage(), 90);
        assertEq(community.treasuryPercentage(), 1);
        assertEq(community.validationsPercentage(), 1);
        assertEq(community.foundationPercentage(), 8);
    }

    function test_setPercents_withoutRole() public {
        vm.prank(address(2));
        vm.expectRevert("ThriveProtocol: must have admin role");
        community.setPercentage(90, 1, 1, 8);

        vm.prank(address(6));
        accessControl.grantRole(ADMIN_ROLE, address(2));
        vm.prank(address(2));
        community.setPercentage(90, 1, 1, 8);
        assertEq(community.rewardsPercentage(), 90);
    }

    function test_setAccessControl() public {
        ThriveProtocolAccessControl accessControlImpl =
            new ThriveProtocolAccessControl();
        bytes memory accessControlData =
            abi.encodeCall(accessControlImpl.initialize, ());
        address accessControlProxy = address(
            new ERC1967Proxy(address(accessControlImpl), accessControlData)
        );
        ThriveProtocolAccessControl newAccessControl =
            ThriveProtocolAccessControl(accessControlProxy);

        vm.prank(address(1));
        community.setAccessControlEnumerable(
            address(newAccessControl), OTHER_ADMIN_ROLE
        );

        address accessAddress = address(community.accessControlEnumerable());
        bytes32 newRole = community.role();
        assertEq(accessAddress, address(newAccessControl));
        assertEq(newRole, OTHER_ADMIN_ROLE);
    }

    function test_sAccessControl_fromNotOwner() public {
        ThriveProtocolAccessControl accessControlImpl =
            new ThriveProtocolAccessControl();
        bytes memory accessControlData =
            abi.encodeCall(accessControlImpl.initialize, ());
        address accessControlProxy = address(
            new ERC1967Proxy(address(accessControlImpl), accessControlData)
        );
        ThriveProtocolAccessControl newAccessControl =
            ThriveProtocolAccessControl(accessControlProxy);

        vm.startPrank(address(2));
        bytes4 selector =
            bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, address(2)));
        community.setAccessControlEnumerable(
            address(newAccessControl), OTHER_ADMIN_ROLE
        );
    }

    /////////////
    // getters //
    /////////////

    function test_getName() public view {
        assertEq(community.name(), "test");
    }

    function test_getRewardsAdmin() public view {
        assertEq(community.rewardsAdmin(), rewardsAdmin);
    }

    function test_getTreasuryAdmin() public view {
        assertEq(community.treasuryAdmin(), treasuryAdmin);
    }

    function test_getValidationsAdmin() public view {
        assertEq(community.validationsAdmin(), validationsAdmin);
    }

    function test_getFoundationAdmin() public view {
        assertEq(community.foundationAdmin(), foundationAdmin);
    }

    function test_getRewardsPercent() public view {
        assertEq(community.rewardsPercentage(), 80);
    }

    function test_getTreasuryPercent() public view {
        assertEq(community.treasuryPercentage(), 5);
    }

    function test_getValidationsPercent() public view {
        assertEq(community.validationsPercentage(), 5);
    }

    function test_getFoundationPercent() public view {
        assertEq(community.foundationPercentage(), 10);
    }
}
