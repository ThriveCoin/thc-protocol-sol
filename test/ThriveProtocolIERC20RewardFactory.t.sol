//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveProtocolIERC20RewardFactory} from "src/ThriveProtocolIERC20RewardFactory.sol";
import {ThriveProtocolIERC20Reward} from "src/ThriveProtocolIERC20Reward.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";
import {MockERC20} from "test/mock/MockERC20.sol"; 

contract ThriveProtocolIERC20RewardFactoryTest is Test {
    bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    ThriveProtocolAccessControl accessControl;
    MockERC20 token;
    ThriveProtocolIERC20RewardFactory factory;

    function setUp() public {
        vm.startPrank(address(1));
        accessControl = new ThriveProtocolAccessControl();
        accessControl.initialize();

        token = new MockERC20("test-token", "TST");

        factory = new ThriveProtocolIERC20RewardFactory();
        factory.initialize();
        vm.stopPrank();
    }

    function test_deploy() public {
        vm.prank(address(1));
        (address rewardImpl, address rewardProxy) = factory.deploy(address(accessControl), ADMIN_ROLE, address(token));

        assertEq(ThriveProtocolIERC20Reward(rewardProxy).role(), ADMIN_ROLE);
    }
}
