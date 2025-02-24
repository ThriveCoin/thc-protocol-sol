// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveStakedVoting} from "../src/ThriveStakedVoting.sol";
import {IThriveStaking} from "../src/interface/IThriveStaking.sol";

contract MockStaking is IThriveStaking {
    // We use a simple mapping where staker data is stored as an array:
    // [0] => amount, [1] => stakingTime, [2] => lastYieldTime.
    mapping(address => uint256[3]) public stakerData;

    function setStaker(
        address user,
        uint256 amount,
        uint256 stakingTime,
        uint256 lastYieldTime
    ) external {
        stakerData[user] = [amount, stakingTime, lastYieldTime];
    }

    function stakers(address user)
        external
        view
        override
        returns (uint256, uint256, uint256)
    {
        uint256[3] memory data = stakerData[user];
        return (data[0], data[1], data[2]);
    }
}

contract ThriveStakedVotingTest is Test {
    ThriveStakedVoting voting;
    MockStaking mockStaking;
    address owner = address(this);
    address user = address(0xBEEF);
    uint256 initialVoteRate = 10;

    event VoteRateUpdated(uint256 newRate);

    function setUp() public {
        mockStaking = new MockStaking();
        voting = new ThriveStakedVoting();
        voting.initialize(address(mockStaking), initialVoteRate);
    }

    function testInitializeSetsParameters() public view {
        assertEq(voting.voteRate(), initialVoteRate);
        assertEq(address(voting.stakingContract()), address(mockStaking));
    }

    function testInitializeRevertsForZeroAddress() public {
        ThriveStakedVoting tempVoting = new ThriveStakedVoting();
        vm.expectRevert("Staking address cannot be zero");
        tempVoting.initialize(address(0), initialVoteRate);
    }

    function testSetVoteRateByOwner() public {
        uint256 newRate = 20;
        vm.expectEmit(true, false, false, true);

        emit VoteRateUpdated(newRate);

        voting.setVoteRate(newRate);
        assertEq(voting.voteRate(), newRate);
    }

    function testSetVoteRateRevertsIfZero() public {
        vm.expectRevert("Vote rate must be greater than zero");
        voting.setVoteRate(0);
    }

    function testSetVoteRateRevertsForNonOwner() public {
        address nonOwner = address(0x1234);
        vm.prank(nonOwner);
        vm.expectRevert();
        voting.setVoteRate(15);
    }

    function testGetVotesReturnsCorrectValue() public {
        uint256 stakedAmount = 100 ether;
        mockStaking.setStaker(
            user, stakedAmount, block.timestamp, block.timestamp
        );

        uint256 expectedVotes = stakedAmount * initialVoteRate;
        uint256 votes = voting.getVotes(user);
        assertEq(votes, expectedVotes);
    }
}
