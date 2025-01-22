// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// This file contains unit tests for the reviewer protocol - ThriveReviewFactory.
// The primary objectives are to validate proper authorization, enforce contract restrictions, ensure functions handle data correctly and operate as intended/per specs.
// Note: Event testing is not included in this file.

import {Test} from "forge-std/Test.sol";

import "../BasicTestConfigs.t.sol";

import "../../../src/ThriveWorkerUnitFactory.sol";
import "../../../src/reviewer-protocol/ThriveReviewFactory.sol";
import "../../../src/reviewer-protocol/ThriveReview.sol";

// @OpenZeppelin imports
import "openzeppelin-foundry-upgrades/Upgrades.sol";

// Command to run this test script:
// forge clean && forge test --match-contract ThriveReviewFactoryUnitTests

contract ThriveReviewFactoryUnitTests is Test, BasicTestConfigs {
    using Upgrades for address;

    ThriveWorkerUnitFactory thriveWorkerUnitFactory;
    ThriveReviewFactory thriveReviewFactory;
    ThriveReview thriveReview;

    address randomUser = address(0x1234);

    address thriveReviewFactoryAddress;

    function setUp() public {
        // Deploy ThriveWorkerUnitFactory
        thriveWorkerUnitFactory = new ThriveWorkerUnitFactory();

        // Deploy ThriveReview
        thriveReview = new ThriveReview();

        // Deploy using UUPS standard
        thriveReviewFactoryAddress = Upgrades.deployUUPSProxy(
            "ThriveReviewFactory.sol",
            abi.encodeCall(
                ThriveReviewFactory.initialize,
                (
                    address(thriveWorkerUnitFactory),
                    address(thriveReview),
                    address(0),
                    address(this)
                )
            )
        );
        thriveReviewFactory = ThriveReviewFactory(thriveReviewFactoryAddress);
    }

    function test01_success_CreateReviewContractAndWorkUnit() public {
        // Test creating a ThriveWorkUnit and ThriveReview contract
        (address thriveReviewContract, address thriveWorkUnitContract) =
        thriveReviewFactory.createWorkUnitAndReviewContract{
            value: REVIEW_CONTRACT_ALLOCATION
        }(workUnitArgs, reviewConfiguration, address(this));

        assertNotEq(
            thriveReviewContract,
            address(0),
            "ThriveReview contract address should not be zero address"
        );
        assertNotEq(
            thriveWorkUnitContract,
            address(0),
            "ThriveWorkUnit contract address should not be zero address"
        );
    }

    function test02_success_CreateOnlyReviewContract() public {
        // Test creating a ThriveWorkUnit and ThriveReview contract
        address thriveReviewContract = thriveReviewFactory.createReviewContract{
            value: REVIEW_CONTRACT_ALLOCATION
        }(reviewConfiguration, address(this));

        assertNotEq(
            thriveReviewContract,
            address(0),
            "ThriveReview contract address should not be zero address"
        );
    }

    function test03_revert_ToCreateContractsWithInsufficientFunds() public {
        // Test creating a ThriveWorkUnit and ThriveReview contract with insufficient funds
        vm.expectRevert(
            "ThriveReviewFactory: Insufficient funds to allocate rewards for reviewers sent"
        );
        thriveReviewFactory.createWorkUnitAndReviewContract{
            value: REVIEW_CONTRACT_ALLOCATION - 1
        }(workUnitArgs, reviewConfiguration, address(this));

        // Test creating a ThriveReview contract with insufficient funds
        vm.expectRevert(
            "ThriveReviewFactory: Insufficient funds to allocate rewards for reviewers sent"
        );
        thriveReviewFactory.createReviewContract{
            value: REVIEW_CONTRACT_ALLOCATION - 1
        }(reviewConfiguration, address(this));
    }

    function test04_revert_ToCreateContractsWithMismatchReviewConfigurationVariables(
    ) public {
        reviewConfiguration.reviewerRewardsTotalAllocation =
            REVIEW_CONTRACT_ALLOCATION - 1;

        // Test creating a ThriveWorkUnit and ThriveReview contract with insufficient funds
        vm.expectRevert(
            "ThriveReviewFactory: Insufficient funds to allocate rewards for reviewers"
        );
        thriveReviewFactory.createWorkUnitAndReviewContract{
            value: REVIEW_CONTRACT_ALLOCATION
        }(workUnitArgs, reviewConfiguration, address(this));

        // Test creating a ThriveReview contract with insufficient funds
        vm.expectRevert(
            "ThriveReviewFactory: Insufficient funds to allocate rewards for reviewers"
        );
        thriveReviewFactory.createReviewContract{
            value: REVIEW_CONTRACT_ALLOCATION
        }(reviewConfiguration, address(this));
    }

    function test05_success_ReviewFactoryProceedFundsToReviewContract()
        public
    {
        // Test creating a ThriveWorkUnit and ThriveReview contract
        (address thriveReviewContract,) = thriveReviewFactory
            .createWorkUnitAndReviewContract{value: REVIEW_CONTRACT_ALLOCATION}(
            workUnitArgs, reviewConfiguration, address(this)
        );

        // Ensure ThriveReview contract has received the funds
        assertEq(
            address(thriveReviewContract).balance,
            REVIEW_CONTRACT_ALLOCATION,
            "ThriveReview contract should have received the funds"
        );

        // Test creating a ThriveWorkUnit and ThriveReview contract
        address thriveReviewContract_2 = thriveReviewFactory
            .createReviewContract{value: REVIEW_CONTRACT_ALLOCATION}(
            reviewConfiguration, address(this)
        );

        // Ensure ThriveReview contract has received the funds
        assertEq(
            address(thriveReviewContract_2).balance,
            REVIEW_CONTRACT_ALLOCATION,
            "ThriveReview contract should have received the funds"
        );
    }

    function test06_success_UpdateAddressesOnReviewFactory() public {
        address newThriveWorkerUnitFactory_ = address(0x1234);
        address newThriveReviewContractImplementation_ = address(0x2345);
        address newBadgeQueryContractAddress_ = address(0x3456);

        thriveReviewFactory.configureSystemContracts(
            newThriveWorkerUnitFactory_,
            newThriveReviewContractImplementation_,
            newBadgeQueryContractAddress_
        );

        assertEq(
            thriveReviewFactory.thriveWorkerUnitFactory(),
            newThriveWorkerUnitFactory_,
            "ThriveWorkerUnitFactory address should be updated"
        );
        assertEq(
            thriveReviewFactory.thriveReviewContractImplementation(),
            newThriveReviewContractImplementation_,
            "ThriveReviewContractImplementation address should be updated"
        );
        assertEq(
            thriveReviewFactory.badgeQueryContractAddress(),
            newBadgeQueryContractAddress_,
            "BadgeQueryContractAddress address should be updated"
        );
    }

    function test07_revert_FailToUpdateAddressesOnReviewFactoryIfNotOwner()
        public
    {
        address newThriveWorkerUnitFactory_ = address(0x1234);
        address newThriveReviewContractImplementation_ = address(0x2345);
        address newBadgeQueryContractAddress_ = address(0x3456);

        // Test updating addresses by non-owner
        vm.prank(randomUser);
        vm.expectRevert();
        thriveReviewFactory.configureSystemContracts(
            newThriveWorkerUnitFactory_,
            newThriveReviewContractImplementation_,
            newBadgeQueryContractAddress_
        );
    }

    function test08_success_UpgradeReviewFactory() public {
        // Store old values to verify they persist after upgrade
        address oldWorkerFactory = thriveReviewFactory.thriveWorkerUnitFactory();
        address oldReviewImpl =
            thriveReviewFactory.thriveReviewContractImplementation();
        address oldBadgeQuery = thriveReviewFactory.badgeQueryContractAddress();

        // Upgrade to new implementation
        Upgrades.upgradeProxy(
            thriveReviewFactoryAddress, "ThriveReviewFactoryV2.sol", bytes("")
        );

        // Cast the proxy to the new implementation type
        ThriveReviewFactory upgradedFactory =
            ThriveReviewFactory(thriveReviewFactoryAddress);

        // Verify storage values persisted
        assertEq(
            upgradedFactory.thriveWorkerUnitFactory(),
            oldWorkerFactory,
            "Worker factory address should persist after upgrade"
        );
        assertEq(
            upgradedFactory.thriveReviewContractImplementation(),
            oldReviewImpl,
            "Review implementation address should persist after upgrade"
        );
        assertEq(
            upgradedFactory.badgeQueryContractAddress(),
            oldBadgeQuery,
            "Badge query address should persist after upgrade"
        );

        // Verify ownership persisted
        assertEq(
            upgradedFactory.owner(),
            address(this),
            "Owner should persist after upgrade"
        );
    }
}
