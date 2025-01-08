// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import "./BasicTestConfigs.t.sol";

import "../../../src/ThriveWorkerUnitFactory.sol";
import "../../../src/reviewer-protocol/ThriveReviewFactory.sol";
import "../../../src/reviewer-protocol/ThriveReview.sol";

import "openzeppelin-foundry-upgrades/Upgrades.sol";


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

    function test01_create_ReviewContractAndWorkUnit() public {

        // Test creating a ThriveWorkUnit and ThriveReview contract
        (address thriveReviewContract, address thriveWorkUnitContract) = thriveReviewFactory.createWorkUnitAndReviewContract{value: 10 ether}(
            workUnitArgs, reviewConfiguration
        );

        assertNotEq(thriveReviewContract, address(0), "ThriveReview contract address should not be zero address");
        assertNotEq(thriveWorkUnitContract, address(0), "ThriveWorkUnit contract address should not be zero address");
    }

    function test03_create_OnlyReviewContract() public {

        // Test creating a ThriveWorkUnit and ThriveReview contract
        address thriveReviewContract = thriveReviewFactory.createReviewContract{value: 10 ether}(reviewConfiguration);

        assertNotEq(thriveReviewContract, address(0), "ThriveReview contract address should not be zero address");
    }

    function test04_fail_ToCreateContractsWithInsufficientFunds() public {

        // Test creating a ThriveWorkUnit and ThriveReview contract with insufficient funds
        vm.expectRevert("ThriveReviewFactory: small reward amount sent");
        thriveReviewFactory.createWorkUnitAndReviewContract{value: REVIEW_CONTRACT_ALLOCATION - 1}(
            workUnitArgs, reviewConfiguration
        );

        vm.expectRevert("ThriveReviewFactory: small reward amount sent");
        thriveReviewFactory.createReviewContract{value: REVIEW_CONTRACT_ALLOCATION - 1}(
            reviewConfiguration
        );

    }

    function test05_ReviewFactoryShouldProceedFundsToReviewContract() public {

        // Test creating a ThriveWorkUnit and ThriveReview contract
        (address thriveReviewContract, ) = thriveReviewFactory.createWorkUnitAndReviewContract{value: REVIEW_CONTRACT_ALLOCATION}(
            workUnitArgs, reviewConfiguration
        );

        // Ensure ThriveReview contract has received the funds
        assertEq(address(thriveReviewContract).balance, REVIEW_CONTRACT_ALLOCATION, "ThriveReview contract should have received the funds");

        // Test creating a ThriveWorkUnit and ThriveReview contract
        address thriveReviewContract_2 = thriveReviewFactory.createReviewContract{value: REVIEW_CONTRACT_ALLOCATION}(
           reviewConfiguration
        );

        // Ensure ThriveReview contract has received the funds
        assertEq(address(thriveReviewContract_2).balance, REVIEW_CONTRACT_ALLOCATION, "ThriveReview contract should have received the funds");

    }

    function test06_fail_ToAddReviewContractOnWorkUnitIfCallerNotModerator() public {

        // Create ThriveWorkUnit
        address thriveWorkUnitContract = thriveWorkerUnitFactory.createThriveWorkUnit(workUnitArgs);

        // Set ThriveWorkUnit address in reviewConfiguration
        reviewConfiguration.workUnit = thriveWorkUnitContract;

        vm.startPrank(randomUser);
        vm.expectRevert();
        thriveReviewFactory.createReviewContract{value: 10 ether}(
           reviewConfiguration
        );
        vm.stopPrank();
    }

}
