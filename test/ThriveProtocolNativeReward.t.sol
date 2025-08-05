// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {ThriveProtocolNativeReward} from "../src/ThriveProtocolNativeReward.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";

contract ThriveProtocolNativeRewardTest is Test {
    bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 OTHER_ADMIN_ROLE = keccak256("OTHER_ADMIN_ROLE");

    ThriveProtocolNativeReward public reward;
    ThriveProtocolAccessControl public accessControl;

    event Reward(address indexed recipient, uint256 amount, string reason);
    event RewardTransferred(
        address indexed recipient, uint256 amount, string reason
    );
    event Withdrawal(address indexed user, uint256 amount);
    event RewardRemoved(
        address indexed recipient, uint256 amount, string reason
    );

    address[] public recipients;
    address payable[] public payableRecipients;
    uint256[] public amounts;
    string[] public reasons;

    address internal constant ADMIN_ADDRESS = address(1);
    address internal constant USER_A_ADDRESS = address(2);
    address internal constant USER_B_ADDRESS = address(3);
    address internal constant NON_ADMIN_ADDRESS = address(4);
    address internal constant ARBITRARY_SENDER = address(5);

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
        payableRecipients = [payable(address(2)), payable(address(3))];
        amounts = [0.001 ether, 0.1 ether];
        reasons = ["deposited", "test"];
    }

    // Helper function to give rewards using ADMIN_ADDRESS
    function _giveRewardAdmin(
        address recipient,
        uint256 amount,
        string memory reason
    ) internal {
        vm.prank(ADMIN_ADDRESS);
        reward.reward(recipient, amount, reason);
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
        vm.prank(USER_A_ADDRESS);
        vm.expectRevert("ThriveProtocol: must have admin role");
        reward.rewardBulk(recipients, amounts, reasons);
    }

    /**
     *
     * Tests for payoutReward (Single)
     *
     */
    function test_payoutReward_Success() public {
        uint256 payoutAmount = 0.5 ether;
        string memory payoutReason = "test payout";
        vm.deal(address(reward), 1 ether);

        uint256 initialRecipientBalance = USER_A_ADDRESS.balance;
        uint256 initialContractBalance = address(reward).balance;

        vm.startPrank(ADMIN_ADDRESS);
        vm.expectEmit(true, true, true, true);
        emit RewardTransferred(USER_A_ADDRESS, payoutAmount, payoutReason);
        reward.payoutReward(payable(USER_A_ADDRESS), payoutAmount, payoutReason);
        vm.stopPrank();

        assertEq(
            USER_A_ADDRESS.balance,
            initialRecipientBalance + payoutAmount,
            "Recipient should receive the funds"
        );
        assertEq(
            address(reward).balance,
            initialContractBalance - payoutAmount,
            "Contract balance should decrease"
        );
    }

    function test_payoutReward_RevertIf_NonAdmin() public {
        vm.deal(address(reward), 1 ether);

        vm.startPrank(NON_ADMIN_ADDRESS);
        vm.expectRevert();
        reward.payoutReward(payable(USER_A_ADDRESS), 0.5 ether, "fail");
        vm.stopPrank();
    }

    function test_payoutReward_RevertIf_InsufficientBalance() public {
        vm.deal(address(reward), 0.1 ether);

        vm.startPrank(ADMIN_ADDRESS);
        vm.expectRevert("ThriveProtocol: Insufficient contract balance");
        reward.payoutReward(payable(USER_A_ADDRESS), 0.5 ether, "fail");
        vm.stopPrank();
    }

    function test_payoutReward_RevertIf_AmountIsZero() public {
        vm.deal(address(reward), 1 ether);

        vm.startPrank(ADMIN_ADDRESS);
        vm.expectRevert(
            "ThriveProtocol: Payout amount must be greater than zero"
        );
        reward.payoutReward(payable(USER_A_ADDRESS), 0, "fail");
        vm.stopPrank();
    }

    /**
     *
     * Tests for payoutRewardBulk
     *
     */
    function test_payoutRewardBulk_Success() public {
        uint256 totalPayout = amounts[0] + amounts[1];
        vm.deal(address(reward), 1 ether);

        uint256 initialRecipientABalance = payableRecipients[0].balance;
        uint256 initialRecipientBBalance = payableRecipients[1].balance;
        uint256 initialContractBalance = address(reward).balance;

        vm.startPrank(ADMIN_ADDRESS);
        vm.expectEmit(true, true, true, true);
        emit RewardTransferred(payableRecipients[0], amounts[0], reasons[0]);
        vm.expectEmit(true, true, true, true);
        emit RewardTransferred(payableRecipients[1], amounts[1], reasons[1]);

        reward.payoutRewardBulk(payableRecipients, amounts, reasons);
        vm.stopPrank();

        assertEq(
            payableRecipients[0].balance,
            initialRecipientABalance + amounts[0],
            "Recipient A balance mismatch"
        );
        assertEq(
            payableRecipients[1].balance,
            initialRecipientBBalance + amounts[1],
            "Recipient B balance mismatch"
        );
        assertEq(
            address(reward).balance,
            initialContractBalance - totalPayout,
            "Contract balance mismatch"
        );
    }

    function test_payoutRewardBulk_RevertIf_NonAdmin() public {
        vm.deal(address(reward), 1 ether);

        vm.startPrank(NON_ADMIN_ADDRESS);
        vm.expectRevert();
        reward.payoutRewardBulk(payableRecipients, amounts, reasons);
        vm.stopPrank();
    }

    function test_payoutRewardBulk_RevertIf_InsufficientBalance() public {
        uint256 totalPayout = amounts[0] + amounts[1];
        vm.deal(address(reward), totalPayout - 1 wei);

        vm.startPrank(ADMIN_ADDRESS);
        vm.expectRevert(
            "ThriveProtocol: Insufficient contract balance for bulk payout"
        );
        reward.payoutRewardBulk(payableRecipients, amounts, reasons);
        vm.stopPrank();
    }

    function test_payoutRewardBulk_RevertIf_ArrayLengthsMismatch() public {
        uint256[] memory mismatchedAmounts = new uint256[](1);
        mismatchedAmounts[0] = 1 ether;

        vm.startPrank(ADMIN_ADDRESS);
        vm.expectRevert("Array lengths mismatch");
        reward.payoutRewardBulk(payableRecipients, mismatchedAmounts, reasons);
        vm.stopPrank();
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

    //////////////////////
    // removeRewardBulk //
    //////////////////////

    function test_RemoveRewardBulk_Success() public {
        uint256 rewardUserA = 1 ether;
        uint256 rewardUserB = 2 ether;
        _giveRewardAdmin(USER_A_ADDRESS, rewardUserA, "Reward A for bulk");
        _giveRewardAdmin(USER_B_ADDRESS, rewardUserB, "Reward B for bulk");

        address[] memory localRecipients = new address[](2);
        localRecipients[0] = USER_A_ADDRESS;
        localRecipients[1] = USER_B_ADDRESS;

        uint256[] memory localAmounts = new uint256[](2);
        localAmounts[0] = 0.2 ether;
        localAmounts[1] = 0.5 ether;

        string[] memory localReasons = new string[](2);
        localReasons[0] = "Bulk remove A";
        localReasons[1] = "Bulk remove B";

        vm.prank(ADMIN_ADDRESS);
        vm.expectEmit(true, true, true, true, address(reward));
        emit RewardRemoved(USER_A_ADDRESS, localAmounts[0], localReasons[0]);
        vm.expectEmit(true, true, true, true, address(reward));
        emit RewardRemoved(USER_B_ADDRESS, localAmounts[1], localReasons[1]);
        reward.removeRewardBulk(localRecipients, localAmounts, localReasons);

        assertEq(
            reward.balanceOf(USER_A_ADDRESS), rewardUserA - localAmounts[0]
        );
        assertEq(
            reward.balanceOf(USER_B_ADDRESS), rewardUserB - localAmounts[1]
        );
    }

    function test_RemoveRewardBulk_Success_MixFullAndPartialAndZero() public {
        address USER_C_ADDRESS = address(5);
        vm.deal(USER_C_ADDRESS, 1 ether);

        _giveRewardAdmin(USER_A_ADDRESS, 1 ether, "Reward A for mix");
        _giveRewardAdmin(USER_B_ADDRESS, 0.5 ether, "Reward B for mix");
        _giveRewardAdmin(USER_C_ADDRESS, 0.7 ether, "Reward C for mix");

        address[] memory localRecipients = new address[](3);
        localRecipients[0] = USER_A_ADDRESS;
        localRecipients[1] = USER_B_ADDRESS;
        localRecipients[2] = USER_C_ADDRESS;

        uint256[] memory localAmounts = new uint256[](3);
        localAmounts[0] = 0.3 ether;
        localAmounts[1] = 0.5 ether;
        localAmounts[2] = 0 ether;

        string[] memory localReasons = new string[](3);
        localReasons[0] = "Partial A";
        localReasons[1] = "Full B";
        localReasons[2] = "Zero C";

        vm.prank(ADMIN_ADDRESS);
        vm.expectEmit(true, true, true, true, address(reward));
        emit RewardRemoved(USER_A_ADDRESS, localAmounts[0], localReasons[0]);
        vm.expectEmit(true, true, true, true, address(reward));
        emit RewardRemoved(USER_B_ADDRESS, localAmounts[1], localReasons[1]);
        vm.expectEmit(true, true, true, true, address(reward));
        emit RewardRemoved(USER_C_ADDRESS, localAmounts[2], localReasons[2]);
        reward.removeRewardBulk(localRecipients, localAmounts, localReasons);

        assertEq(reward.balanceOf(USER_A_ADDRESS), 1 ether - 0.3 ether);
        assertEq(reward.balanceOf(USER_B_ADDRESS), 0);
        assertEq(reward.balanceOf(USER_C_ADDRESS), 0.7 ether);
    }

    function test_RemoveRewardBulk_Fail_NotAdmin() public {
        _giveRewardAdmin(USER_A_ADDRESS, 1 ether, "Reward for bulk auth test");

        address[] memory localRecipients = new address[](1);
        localRecipients[0] = USER_A_ADDRESS;
        uint256[] memory localAmounts = new uint256[](1);
        localAmounts[0] = 0.1 ether;
        string[] memory localReasons = new string[](1);
        localReasons[0] = "Attempt non-admin";

        vm.prank(NON_ADMIN_ADDRESS);
        vm.expectRevert("ThriveProtocol: must have admin role");
        reward.removeRewardBulk(localRecipients, localAmounts, localReasons);
    }

    function test_RemoveRewardBulk_Fail_MismatchedArrayLengths_RecipientsAmounts(
    ) public {
        address[] memory localRecipients = new address[](1);
        localRecipients[0] = USER_A_ADDRESS;
        uint256[] memory localAmounts = new uint256[](2);
        localAmounts[0] = 0.1 ether;
        localAmounts[1] = 0.1 ether;
        string[] memory localReasons = new string[](1);
        localReasons[0] = "Mismatch test";

        vm.prank(ADMIN_ADDRESS);
        vm.expectRevert(bytes("ThriveProtocol: array lengths mismatch!"));
        reward.removeRewardBulk(localRecipients, localAmounts, localReasons);
    }

    function test_RemoveRewardBulk_Fail_MismatchedArrayLengths_RecipientsReasons(
    ) public {
        address[] memory localRecipients = new address[](1);
        localRecipients[0] = USER_A_ADDRESS;
        uint256[] memory localAmounts = new uint256[](1);
        localAmounts[0] = 0.1 ether;
        string[] memory localReasons = new string[](2);
        localReasons[0] = "R1";
        localReasons[1] = "R2";

        vm.prank(ADMIN_ADDRESS);
        vm.expectRevert(bytes("ThriveProtocol: array lengths mismatch!"));
        reward.removeRewardBulk(localRecipients, localAmounts, localReasons);
    }

    function test_RemoveRewardBulk_Fail_OneAmountExceedsBalance() public {
        _giveRewardAdmin(USER_A_ADDRESS, 0.1 ether, "Reward A for exceed test");
        _giveRewardAdmin(USER_B_ADDRESS, 0.5 ether, "Reward B for exceed test");

        address[] memory localRecipients = new address[](2);
        localRecipients[0] = USER_A_ADDRESS;
        localRecipients[1] = USER_B_ADDRESS;

        uint256[] memory localAmounts = new uint256[](2);
        localAmounts[0] = 0.05 ether;
        localAmounts[1] = 0.6 ether;

        string[] memory localReasons = new string[](2);
        localReasons[0] = "Valid A";
        localReasons[1] = "Exceed B";

        vm.prank(ADMIN_ADDRESS);
        vm.expectRevert(bytes("ThriveProtocol: amount exceeds balance!"));
        reward.removeRewardBulk(localRecipients, localAmounts, localReasons);

        assertEq(reward.balanceOf(USER_A_ADDRESS), 0.1 ether);
        assertEq(reward.balanceOf(USER_B_ADDRESS), 0.5 ether);
    }

    function test_RemoveRewardBulk_Success_EmptyArrays() public {
        address[] memory localRecipients = new address[](0);
        uint256[] memory localAmounts = new uint256[](0);
        string[] memory localReasons = new string[](0);

        vm.prank(ADMIN_ADDRESS);
        reward.removeRewardBulk(localRecipients, localAmounts, localReasons);
    }

    function test_RemoveRewardBulk_Success_SingleUserInBulk() public {
        uint256 initialReward = 0.7 ether;
        _giveRewardAdmin(
            USER_A_ADDRESS, initialReward, "Reward for single bulk test"
        );

        address[] memory localRecipients = new address[](1);
        localRecipients[0] = USER_A_ADDRESS;
        uint256[] memory localAmounts = new uint256[](1);
        localAmounts[0] = 0.2 ether;
        string[] memory localReasons = new string[](1);
        localReasons[0] = "Single bulk remove";

        vm.prank(ADMIN_ADDRESS);
        vm.expectEmit(true, true, true, true, address(reward));
        emit RewardRemoved(USER_A_ADDRESS, localAmounts[0], localReasons[0]);
        reward.removeRewardBulk(localRecipients, localAmounts, localReasons);

        assertEq(
            reward.balanceOf(USER_A_ADDRESS), initialReward - localAmounts[0]
        );
    }
}
