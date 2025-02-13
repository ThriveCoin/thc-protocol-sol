// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IThriveStaking} from "./interface/IThriveStaking.sol";

/**
 * @title Staked Thrive's Voting Contract
 * @notice Provides a comprehensive vote count across the pool in the ThriveStaking contract
 */
contract ThriveStakedVotingUpgradeable is OwnableUpgradeable {
    IThriveStaking public stakingContract;

    function initialize(address _stakingContractAddress) external initializer {
        require(
            _stakingContractAddress != address(0),
            "Staking address cannot be zero"
        );
        __Ownable_init(msg.sender);
        stakingContract = IThriveStaking(_stakingContractAddress);
    }

    function getVotes(address user) external view returns (uint256 votes) {
        (uint256 amount,,) = stakingContract.stakers(user);
        votes = amount;
    }
}
