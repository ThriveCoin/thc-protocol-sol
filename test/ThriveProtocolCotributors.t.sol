//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import "test/mock/MockAccessControl.sol";
import {ThriveProtocolContributors} from "src/ThriveProtocolContributors.sol";
import {ThriveProtocolContributions} from "src/ThriveProtocolContributions.sol";

contract ThriveProtocolContributorsTest is Test {
    bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");

    MockAccessControl accessControl;
    MockERC20 token;
    ThriveProtocolContributors contributors;
    ThriveProtocolContributions contributions;

    ThriveProtocolContributors.ValidatorReward[] validatorRewards;

    function setUp() public {
        vm.startPrank(address(6));
        accessControl = new MockAccessControl();
        accessControl.grantRole(ADMIN_ROLE, address(1));
        vm.stopPrank();

        token = new MockERC20("token", "tkn");

        contributions = new ThriveProtocolContributions();
        contributors = new ThriveProtocolContributors();
        contributors.initialize(address(contributions));
    }

    function test_validatedContribution() public {
        ThriveProtocolContributors.ValidatorReward memory reward1 =
            ThriveProtocolContributors.ValidatorReward(address(3), 800);
        validatorRewards.push(reward1);
        ThriveProtocolContributors.ValidatorReward memory reward2 =
            ThriveProtocolContributors.ValidatorReward(address(4), 50);
        validatorRewards.push(reward2);
        ThriveProtocolContributors.ValidatorReward memory reward3 =
            ThriveProtocolContributors.ValidatorReward(address(5), 50);
        validatorRewards.push(reward3);
        ThriveProtocolContributors.ValidatorReward memory reward4 =
            ThriveProtocolContributors.ValidatorReward(address(6), 100);
        validatorRewards.push(reward4);

        vm.prank(address(1));
        contributions.addContribution(
            "test", "123", "test-test", address(2), 1000, 100
        );

        vm.prank(address(2));
        contributors.addValidatedContribution(
            0, "test-test", "0x002", "123", "0xeb0034", 4, validatorRewards
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
        ) = contributors.getValidatedContribution(0);

        assertEq(id, 0);
        assertEq(metadata, "test-test");
        assertEq(validator_address, "0x002");
        assertEq(chain_address, "123");
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

    function test_addValidatedContribution_fronNotValidator() public {
        ThriveProtocolContributors.ValidatorReward memory reward1 =
            ThriveProtocolContributors.ValidatorReward(address(3), 800);
        validatorRewards.push(reward1);
        ThriveProtocolContributors.ValidatorReward memory reward2 =
            ThriveProtocolContributors.ValidatorReward(address(4), 50);
        validatorRewards.push(reward2);
        ThriveProtocolContributors.ValidatorReward memory reward3 =
            ThriveProtocolContributors.ValidatorReward(address(5), 50);
        validatorRewards.push(reward3);
        ThriveProtocolContributors.ValidatorReward memory reward4 =
            ThriveProtocolContributors.ValidatorReward(address(6), 100);
        validatorRewards.push(reward4);

        vm.prank(address(1));
        contributions.addContribution(
            "test", "123", "test-test", address(2), 1000, 100
        );

        vm.startPrank(address(1));
        vm.expectRevert("ThriveProtocol: not a validator of contribution");
        contributors.addValidatedContribution(
            0, "test-test", "0x002", "123", "0xeb0034", 4, validatorRewards
        );
        vm.stopPrank();
    }

    function test_validatedContributionsCount() public {
        assertEq(contributors.validatedContributionCount(), 0);

        ThriveProtocolContributors.ValidatorReward memory reward1 =
            ThriveProtocolContributors.ValidatorReward(address(3), 800);
        validatorRewards.push(reward1);
        ThriveProtocolContributors.ValidatorReward memory reward2 =
            ThriveProtocolContributors.ValidatorReward(address(4), 50);
        validatorRewards.push(reward2);
        ThriveProtocolContributors.ValidatorReward memory reward3 =
            ThriveProtocolContributors.ValidatorReward(address(5), 50);
        validatorRewards.push(reward3);
        ThriveProtocolContributors.ValidatorReward memory reward4 =
            ThriveProtocolContributors.ValidatorReward(address(6), 100);
        validatorRewards.push(reward4);

        vm.prank(address(1));
        contributions.addContribution(
            "test", "123", "test-test", address(2), 1000, 100
        );

        vm.prank(address(2));
        contributors.addValidatedContribution(
            0, "test-test", "0x002", "123", "0xeb0034", 4, validatorRewards
        );

        assertEq(contributors.validatedContributionCount(), 1);
    }
}
