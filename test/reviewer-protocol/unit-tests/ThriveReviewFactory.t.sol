// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import "./BasicTestConfigs.t.sol";

import "../../../src/reviewer-protocol/ThriveReviewFactory.sol";

contract ThriveReviewFactoryUnitTests is Test, BasicTestConfigs {
    ThriveReviewFactory thriveReviewFactory;

    function setUp() public {
        // Set up before each test

        thriveReviewFactory = new ThriveReviewFactory();
    }

    function test_create_ReviewContractAndWorkUnit() public {
            // Test creating a ThriveWorkUnit and ThriveReview contract
    }

    function test_create_ReviewContractWithExistingWorkUnit() public {
        // Test creating a ThriveWorkUnit and ThriveReview contract
    }

    function test_create_OnlyReviewContract() public {
        // Test creating a ThriveWorkUnit and ThriveReview contract
    }
}
