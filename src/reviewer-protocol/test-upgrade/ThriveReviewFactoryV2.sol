// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


/// @custom:oz-upgrades-from ThriveReviewFactory
contract ThriveReviewFactoryV2 is
    OwnableUpgradeable,
    UUPSUpgradeable
{


    /**
     * STORAGE VARIABLES
     */

    // Address of the ThriveWorkerUnitFactory contract
    address public thriveWorkerUnitFactory;

    // Address of the ThriveReview contract implementation
    address public thriveReviewContractImplementation;

    // Address of the BadgeQuery contract
    address public badgeQueryContractAddress;
    
    // Leave gap for storage variables to be added in the future
    uint256[50] private __gap;

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

}