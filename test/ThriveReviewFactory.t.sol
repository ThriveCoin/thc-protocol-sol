// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import "../src/reviewer-protocol/ThriveReviewFactory.sol";

contract ThriveReviewFactoryUnitTest is Test {
    ThriveReviewFactory thriveReviewFactory;

    function setUp() public {
        thriveReviewFactory = new ThriveReviewFactory();
    }

    function testCreateReviewContract() public {
        assertNotEq(thriveReviewFactory.createReviewContract(), address(0), "Review contract address is zero");
    }
}
