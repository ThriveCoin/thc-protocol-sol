//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import "test/mock/MockAccessControl.sol";
import {ThriveProtocolContributors} from "src/ThriveProtocolContributors.sol";

contract ThriveProtocolContributorsTest is Test {
    bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");

    MockAccessControl accessControl;
    MockERC20 token;
    ThriveProtocolContributors contributors;

    ThriveProtocolContributors.ValidatorReward[] validatorRewards;

    function setUp() public {
        vm.startPrank(address(6));
        accessControl = new MockAccessControl();
        accessControl.grantRole(ADMIN_ROLE, address(1));
        vm.stopPrank();

        token = new MockERC20("token", "tkn");

        contributors =
            new ThriveProtocolContributors(address(accessControl), ADMIN_ROLE);
    }

    function test_validatedContribution() public {
        ThriveProtocolContributors.ValidatorReward memory reward1 = ThriveProtocolContributors.ValidatorReward(address(3), 800);
        validatorRewards.push(reward1);
        ThriveProtocolContributors.ValidatorReward memory reward2 = ThriveProtocolContributors.ValidatorReward(address(4), 50);
        validatorRewards.push(reward2);
        ThriveProtocolContributors.ValidatorReward memory reward3 = ThriveProtocolContributors.ValidatorReward(address(5), 50);
        validatorRewards.push(reward3);
        ThriveProtocolContributors.ValidatorReward memory reward4 = ThriveProtocolContributors.ValidatorReward(address(6), 100);
        validatorRewards.push(reward4);

        vm.prank(address(1));
        contributors.addValidatedContribution(
            111, "test", "0x002", "chain", "0xeb0034", 4, validatorRewards
        );

        (
            uint id,
            string memory metadata,
            string memory validator_address,
            string memory chain_address,
            string memory token_contribution,
            uint reward,
            ThriveProtocolContributors.ValidatorReward[] memory
                validators_rewards
        ) = contributors.getValidatedContribution(111);

        assertEq(id, 111);
        assertEq(metadata, "test");
        assertEq(validator_address, "0x002");
        assertEq(chain_address, "chain");
        assertEq(token_contribution, "0xeb0034");
        assertEq(reward, 4);
        assertEq(validators_rewards.length, validatorRewards.length);
        assertEq(validators_rewards.length, 4);

        assertEq(validators_rewards[0].validator, validatorRewards[0].validator);
        assertEq(validators_rewards[0].reward, validatorRewards[0].reward);
        assertEq(validators_rewards[1].validator, validatorRewards[1].validator);
        assertEq(validators_rewards[1].reward, validatorRewards[1].reward);
        assertEq(validators_rewards[2].validator, validatorRewards[2].validator);
        assertEq(validators_rewards[2].reward, validatorRewards[2].reward);
        assertEq(validators_rewards[3].validator, validatorRewards[3].validator);
        assertEq(validators_rewards[3].reward, validatorRewards[3].reward);
    }

    function test_validatedContributionsCount() public {
        assertEq(contributors.validatedContributionCount(), 0);

        ThriveProtocolContributors.ValidatorReward memory reward1 = ThriveProtocolContributors.ValidatorReward(address(3), 800);
        validatorRewards.push(reward1);
        ThriveProtocolContributors.ValidatorReward memory reward2 = ThriveProtocolContributors.ValidatorReward(address(4), 50);
        validatorRewards.push(reward2);
        ThriveProtocolContributors.ValidatorReward memory reward3 = ThriveProtocolContributors.ValidatorReward(address(5), 50);
        validatorRewards.push(reward3);
        ThriveProtocolContributors.ValidatorReward memory reward4 = ThriveProtocolContributors.ValidatorReward(address(6), 100);
        validatorRewards.push(reward4);

        vm.prank(address(1));
        contributors.addValidatedContribution(
            111, "test", "0x002", "chain", "0xeb0034", 4, validatorRewards
        );

        assertEq(contributors.validatedContributionCount(), 1);
    }

    function test_setAccessControl() public {
        MockAccessControl newAccessControl = new MockAccessControl();

        vm.prank(address(1));
        contributors.setAccessControlEnumerable(address(newAccessControl), 0x0000000000000000000000000000000000000000000000000000000000000111);

        address accessAddress = address(contributors.accessControlEnumerable());
        assertEq(accessAddress, address(newAccessControl));
        assertEq(contributors.adminRole(), 0x0000000000000000000000000000000000000000000000000000000000000111);
    }

    function test_sAccessControl_fromNotAdmin() public {
        MockAccessControl newAccessControl = new MockAccessControl();

        vm.startPrank(address(2));
        vm.expectRevert("ThriveProtocol: must have admin role");
        contributors.setAccessControlEnumerable(address(newAccessControl), 0x0000000000000000000000000000000000000000000000000000000000000111);
    }
}