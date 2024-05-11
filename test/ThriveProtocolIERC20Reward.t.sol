// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveProtocolIERC20Reward} from "../src/ThriveProtocolIERC20Reward.sol";
import {MockAccessControl} from "test/mock/MockAccessControl.sol";
import {MockERC20} from "test/mock/MockERC20.sol";

contract ThriveProtocolIERC20RewardTest is Test {
    bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 OTHER_ADMIN_ROLE = keccak256("OTHER_ADMIN_ROLE");

    ThriveProtocolIERC20Reward public reward;
    MockAccessControl public admins;

    MockERC20 public token;

    event Reward(address indexed recipient, uint256 amount, string reason);
    event Withdrawal(address indexed user, uint256 amount);

    address[] public recipients;
    uint256[] public amounts;
    string[] public reasons;

    function setUp() public {
        token = new MockERC20("test token", "TST");
        vm.startPrank(address(1));
        admins = new MockAccessControl();
        admins.grantRole(ADMIN_ROLE, address(1));
        reward = new ThriveProtocolIERC20Reward();
        reward.initialize(address(admins), ADMIN_ROLE, address(token));
        vm.stopPrank();

        token.mint(address(2), 10 ether);

        recipients = [address(2), address(3)];
        amounts = [0.001 ether, 0.1 ether];
        reasons = ["deposited", "test"];
    }

    /////////////
    // deposit //
    /////////////

    function test_Deposit() public {
        vm.startPrank(address(2));
        token.approve(address(reward), 1 ether);
        uint256 rewardBalance = token.balanceOf(address(reward));
        reward.deposit(1 ether);
        vm.stopPrank();
        assertEq(token.balanceOf(address(reward)), rewardBalance + 1 ether);
    }

    function test_DepositWithoutAllowance() public {
        vm.startPrank(address(1));
        bytes4 selector = bytes4(keccak256("ERC20InsufficientAllowance(address,uint256,uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, address(reward), 0, 1 ether));
        reward.deposit(1 ether);
    }

    function test_DepositWithLowAllowance() public {
        vm.startPrank(address(2));
        token.approve(address(reward), 0.5 ether);
        bytes4 selector = bytes4(keccak256("ERC20InsufficientAllowance(address,uint256,uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, address(reward), 0.5 ether, 1 ether));
        reward.deposit(1 ether);
        vm.stopPrank();
    }

    ////////////
    // reward //
    ////////////

    function test_Reward() public {
        vm.prank(address(1));
        vm.expectEmit(true, true, true, true);
        emit Reward(address(2), 0.001 ether, "deposited");
        reward.reward(recipients[0], amounts[0], reasons[0]);

        assertEq(reward.balanceOf(address(2)), 0.001 ether);
    }

    function test_RewardWithoutAdminRole() public {
        vm.prank(address(2));
        vm.expectRevert("ThriveProtocol: must have admin role");
        reward.reward(recipients[0], amounts[0], reasons[0]);
    }

    ////////////////
    // rewardBulk //
    ////////////////

    function test_RewardBulk() public {
        vm.prank(address(1));
        vm.expectEmit(true, true, true, true);
        emit Reward(address(2), 0.001 ether, "deposited");
        vm.expectEmit(true, true, true, true);
        emit Reward(address(3), 0.1 ether, "test");
        reward.rewardBulk(recipients, amounts, reasons);

        assertEq(reward.balanceOf(address(2)), 0.001 ether);
        assertEq(reward.balanceOf(address(3)), 0.1 ether);
    }

    function test_RewardBulkWithMismachtedArrays() public {
        amounts.push(uint256(1 ether));
        recipients.pop();
        vm.prank(address(1));
        vm.expectRevert("Array lengths mismatch");
        reward.rewardBulk(recipients, amounts, reasons);
    }

    function test_RewardBulkWithoutAdminRole() public {
        vm.prank(address(2));
        vm.expectRevert("ThriveProtocol: must have admin role");
        reward.rewardBulk(recipients, amounts, reasons);
    }

    //////////////
    // withdraw //
    //////////////

    function test_Withdraw() public {
        test_Deposit();
        test_Reward();
        uint256 userBalance = token.balanceOf(address(2));
        vm.prank(address(2));
        vm.expectEmit(true, true, true, true);
        emit Withdrawal(address(2), 0.001 ether);
        reward.withdraw(0.001 ether);

        assertEq(reward.balanceOf(address(2)), 0);
        assertEq(token.balanceOf(address(2)), userBalance + 0.001 ether);
    }

    function test_WithdrawTooMuchReward() public {
        test_Deposit();
        test_Reward();
        vm.prank(address(2));
        vm.expectRevert("Insufficient balance");
        reward.withdraw(0.1 ether);
    }

    function test_WithdrawWithLowContractBalance() public {
        test_Reward();
        vm.prank(address(2));
        vm.expectRevert("Insufficient contract balance");
        reward.withdraw(0.001 ether);
    }

    ////////////////////////////////
    // setAccessControlEnumerable //
    ////////////////////////////////

    function test_SetAccessControl() public {
        MockAccessControl newAccessControl = new MockAccessControl();

        vm.prank(address(1));
        reward.setAccessControlEnumerable(
            address(newAccessControl), OTHER_ADMIN_ROLE
        );

        address accessAddress = address(reward.accessControlEnumerable());
        bytes32 newRole = reward.role();
        assertEq(accessAddress, address(newAccessControl));
        assertEq(newRole, OTHER_ADMIN_ROLE);
    }

    function test_AccessControlFromNotOwner() public {
        MockAccessControl newAccessControl = new MockAccessControl();

        vm.startPrank(address(2));
        bytes4 selector =
            bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, address(2)));
        reward.setAccessControlEnumerable(
            address(newAccessControl), OTHER_ADMIN_ROLE
        );
    }
}
