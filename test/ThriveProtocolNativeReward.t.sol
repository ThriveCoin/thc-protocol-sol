// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveProtocolNativeReward} from "../src/ThriveProtocolNativeReward.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";
import {MockERC20} from "test/mock/MockERC20.sol";

contract ThriveProtocolNativeRewardTest is Test {
    bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 OTHER_ADMIN_ROLE = keccak256("OTHER_ADMIN_ROLE");

    ThriveProtocolNativeReward public reward;
    ThriveProtocolAccessControl public accessControl;

    event Reward(address indexed recipient, uint256 amount, string reason);
    event Withdrawal(address indexed user, uint256 amount);

    address[] public recipients;
    uint256[] public amounts;
    string[] public reasons;

    function setUp() public {
        vm.startPrank(address(1));
        ThriveProtocolAccessControl accessControlImpl =
            new ThriveProtocolAccessControl();
        bytes memory accessControlData =
            abi.encodeCall(accessControlImpl.initialize, ());
        address accessControlProxy = address(
            new ERC1967Proxy(address(accessControlImpl), accessControlData)
        );
        accessControl = ThriveProtocolAccessControl(accessControlProxy);
        accessControl.grantRole(ADMIN_ROLE, address(1));

        ThriveProtocolNativeReward rewardImpl = new ThriveProtocolNativeReward();
        bytes memory rewardData = abi.encodeCall(
            rewardImpl.initialize, (address(accessControl), ADMIN_ROLE)
        );
        address rewardProxy =
            address(new ERC1967Proxy(address(rewardImpl), rewardData));
        reward = ThriveProtocolNativeReward(payable(rewardProxy));
        vm.stopPrank();

        recipients = [address(2), address(3)];
        amounts = [0.001 ether, 0.1 ether];
        reasons = ["deposited", "test"];
    }

    /////////////
    // deposit //
    /////////////

    function test_Deposit() public {
        vm.startPrank(address(2));

        deal(address(2), 2 ether);
        assertEq(address(2).balance, 2 ether);

        reward.deposit{value: 1 ether}();

        assertEq(address(2).balance, 1 ether);
        assertEq(address(reward).balance, 1 ether);

        vm.stopPrank();
    }

    function test_DepositNoValue() public {
        vm.startPrank(address(1));
        vm.expectRevert("Deposit amount must be greater than zero");
        reward.deposit{value: 0}();
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

    // ////////////////
    // // rewardBulk //
    // ////////////////

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

    // //////////////
    // // withdraw //
    // //////////////

    function test_Withdraw() public {
        test_Deposit();
        test_Reward();
        uint256 userBalance = address(2).balance;
        vm.prank(address(2));
        vm.expectEmit(true, true, true, true);
        emit Withdrawal(address(2), 0.001 ether);
        reward.withdraw(0.001 ether);

        assertEq(reward.balanceOf(address(2)), 0);
        assertEq(address(2).balance, userBalance + 0.001 ether);
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
        reward.setAccessControlEnumerable(
            address(newAccessControl), OTHER_ADMIN_ROLE
        );

        address accessAddress = address(reward.accessControlEnumerable());
        bytes32 newRole = reward.role();
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

        vm.startPrank(address(2));
        bytes4 selector =
            bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, address(2)));
        reward.setAccessControlEnumerable(
            address(newAccessControl), OTHER_ADMIN_ROLE
        );
        vm.stopPrank();
    }
}
