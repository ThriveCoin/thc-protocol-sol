// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import "../src/ThriveWorkerUnitFactory.sol";
import "../src/reviewer-protocol/ThriveReviewFactory.sol";
import "../src/reviewer-protocol/ThriveReview.sol";
import "../src/interface/IThriveWorkerUnit.sol";


import "openzeppelin-foundry-upgrades/Upgrades.sol";



// This is the deployment script that will deploy the ThriveReviewFactory contract
// which will be used to create new ThriveReview && ThriveWorkerUnit contracts OR
// to deploy only ThriveReview contracts

// The deployment script will be executed by the deployer account whose private key is stored in the .env file
contract ThriveReviewFactoryDeployScript is Script {


    // How to run this script - deploy and verify contracts on blockscout explorer:
    // forge script script/ThriveReviewFactory.s.sol:ThriveReviewFactoryDeployScript --rpc-url https://rpc.abc-thrive.t.raas.gelato.cloud/ --broadcast --verify --verifier blockscout --verifier-url 'https://abc-thrive.cloud.blockscout.com/api/'


    function run() external {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");


        vm.startBroadcast(deployerPrivateKey);

        // Deploy ThriveWorkerUnitFactory
        ThriveWorkerUnitFactory thriveWorkerUnitFactory = new ThriveWorkerUnitFactory();

        // Deploy ThriveReview implementation
        ThriveReview thriveReviewImplementation = new ThriveReview();


        // Deploy using UUPS standard
        address thriveReviewFactoryAddress = Upgrades.deployUUPSProxy(
            "ThriveReviewFactory.sol",
            abi.encodeCall(
                ThriveReviewFactory.initialize,
                (
                    address(thriveWorkerUnitFactory),
                    address(thriveReviewImplementation),
                    address(0),                                 // BADGE QUERY CONTRACT ADDRESS
                    address(this)                               // @dev CHANGE OWNER TO THRIVE WALLET
                )
            )
        );

        vm.stopBroadcast();


        console2.log("ThriveReviewFactory proxy address: ", thriveReviewFactoryAddress);
    }
}
