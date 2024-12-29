// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import "./BasicTestConfigs.t.sol";

import "../../../src/reviewer-protocol/ThriveReviewFactory.sol";

contract ThriveReviewFactoryUnitTests is Test, BasicTestConfigs {
    ThriveReviewFactory thriveReviewFactory;

    function setUp() public {
        // Set up before each test

        // how to deploy uups in foundry ?
        thriveReviewFactory = new ThriveReviewFactory();
    }

    function testSuccess_createWorkUnitAndReview() public { // Big q - how to name test cases ?
            // Test creating a ThriveWorkUnit and ThriveReview contract
    }

    function testSuccess_createReviewContractForExistingWorkUnit() public {
        // Test creating a ThriveWorkUnit and ThriveReview contract
    }

    function testSuccess_createOnlyReviewContract() public {
        // Test creating a ThriveWorkUnit and ThriveReview contract
    }
}
