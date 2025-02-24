// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IThriveStaking} from "./interface/IThriveStaking.sol";

/**
 * @title Staked Thrive's Voting Contract
 * @notice Provides a comprehensive vote count across the pool in the ThriveStaking contract
 */
contract ThriveStakedVoting is OwnableUpgradeable {
    IThriveStaking public stakingContract;
    uint256 public voteRate; // Multiplier that determines the voting power per staked token.

    event VoteRateUpdated(uint256 newRate);

    function initialize(address _stakingContractAddress, uint256 _voteRate)
        external
        initializer
    {
        require(
            _stakingContractAddress != address(0),
            "Staking address cannot be zero"
        );
        __Ownable_init(msg.sender);
        stakingContract = IThriveStaking(_stakingContractAddress);
        voteRate = _voteRate;
    }

    /// @notice Allows owner to update the voting rate multiplier
    function setVoteRate(uint256 _newRate) external onlyOwner {
        require(_newRate > 0, "Vote rate must be greater than zero");
        voteRate = _newRate;

        emit VoteRateUpdated(_newRate);
    }

    function getVotes(address user) external view returns (uint256 votes) {
        (uint256 amount,,) = stakingContract.stakers(user);
        votes = amount * voteRate;
    }
}
