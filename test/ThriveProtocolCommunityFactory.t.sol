//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveProtocolCommunity} from "src/ThriveProtocolCommunity.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";
import {ThriveProtocolCommunityFactory} from
    "src/ThriveProtocolCommunityFactory.sol";

contract ThriveProtocolCommunityFactoryTest is Test {
    bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");

    ThriveProtocolCommunityFactory factory;
    ThriveProtocolAccessControl accessControl;

    address rewardsAdmin;
    address treasuryAdmin;
    address validationsAdmin;
    address foundationAdmin;

    function setUp() public {
        rewardsAdmin = address(2);
        treasuryAdmin = address(3);
        validationsAdmin = address(4);
        foundationAdmin = address(5);

        vm.startPrank(address(6));
        ThriveProtocolAccessControl accessControlImpl =
            new ThriveProtocolAccessControl();
        bytes memory accessControlData =
            abi.encodeCall(accessControlImpl.initialize, ());
        address accessControlProxy = address(
            new ERC1967Proxy(address(accessControlImpl), accessControlData)
        );
        accessControl = ThriveProtocolAccessControl(accessControlProxy);
        vm.stopPrank();

        vm.startPrank(address(1));
        ThriveProtocolCommunityFactory factoryImpl =
            new ThriveProtocolCommunityFactory();
        bytes memory factoryData = abi.encodeCall(factoryImpl.initialize, ());
        address factoryProxy =
            address(new ERC1967Proxy(address(factoryImpl), factoryData));
        factory = ThriveProtocolCommunityFactory(factoryProxy);
        vm.stopPrank();
    }

    ////////////
    // deploy //
    ////////////

    function test_deploy() public {
        vm.startPrank(address(1));
        (address communityImpl, address communityProxy) = factory.deploy(
            "test",
            [rewardsAdmin, treasuryAdmin, validationsAdmin, foundationAdmin],
            [uint256(80), 5, 5, 10],
            address(accessControl),
            ADMIN_ROLE
        );
        vm.stopPrank();

        assertEq(communityImpl != address(0), true);
        assertEq(communityProxy != address (0), true);

        assertEq(ThriveProtocolCommunity(communityProxy).name(), "test");
        assertEq(ThriveProtocolCommunity(communityProxy).rewardsAdmin(), rewardsAdmin);
        assertEq(ThriveProtocolCommunity(communityProxy).treasuryAdmin(), treasuryAdmin);
        assertEq(ThriveProtocolCommunity(communityProxy).validationsAdmin(), validationsAdmin);
        assertEq(ThriveProtocolCommunity(communityProxy).foundationAdmin(), foundationAdmin);
        assertEq(ThriveProtocolCommunity(communityProxy).rewardsPercentage(), uint256(80));
        assertEq(ThriveProtocolCommunity(communityProxy).treasuryPercentage(), uint256(5));
        assertEq(ThriveProtocolCommunity(communityProxy).validationsPercentage(), uint256(5));
        assertEq(ThriveProtocolCommunity(communityProxy).foundationPercentage(), uint256(10));
        assertEq(address(ThriveProtocolCommunity(communityProxy).accessControlEnumerable()), address(accessControl));
        assertEq(ThriveProtocolCommunity(communityProxy).role(), ADMIN_ROLE);
    }
}
