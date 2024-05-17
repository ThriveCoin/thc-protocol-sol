//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveProtocolIERC20RewardFactory} from
    "src/ThriveProtocolIERC20RewardFactory.sol";
import {ThriveProtocolIERC20Reward} from "src/ThriveProtocolIERC20Reward.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockERC20} from "test/mock/MockERC20.sol";

contract ThriveProtocolIERC20RewardFactoryTest is Test {
    bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");

    ThriveProtocolAccessControl accessControl;
    MockERC20 token;
    ThriveProtocolIERC20RewardFactory factory;

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

        ThriveProtocolIERC20RewardFactory factoryImpl =
            new ThriveProtocolIERC20RewardFactory();
        bytes memory factoryData = abi.encodeCall(factoryImpl.initialize, ());
        address factoryProxy =
            address(new ERC1967Proxy(address(factoryImpl), factoryData));
        factory = ThriveProtocolIERC20RewardFactory(factoryProxy);

        token = new MockERC20("test-token", "TST");
        vm.stopPrank();
    }

    function test_deploy() public {
        vm.prank(address(1));
        (address rewardImpl, address rewardProxy) =
            factory.deploy(address(accessControl), ADMIN_ROLE, address(token));

        assertEq(rewardImpl != address(0), true);
        assertEq(rewardProxy != address(0), true);
        
        assertEq(address(ThriveProtocolIERC20Reward(rewardProxy).accessControlEnumerable()), address(accessControl));
        assertEq(address(ThriveProtocolIERC20Reward(rewardProxy).token()), address(token));
        assertEq(ThriveProtocolIERC20Reward(rewardProxy).role(), ADMIN_ROLE);
    }
}
