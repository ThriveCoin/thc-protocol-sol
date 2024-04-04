//SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ThriveProtocolCommunity} from "src/ThriveProtocolCommunity.sol";
import "test/mock/MockAccessControl.sol";
import "src/ThriveProtocolCommunityFactory.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract ThriveProtocolCommunityFactoryTest is Test {
    ThriveProtocolCommunityFactory factory;
    MockAccessControl accessControl;

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
        accessControl = new MockAccessControl();
        accessControl.grantRole(0x00, address(1));
        vm.stopPrank();

        vm.prank(address(1));
        factory = new ThriveProtocolCommunityFactory(
            rewardsAdmin,
            treasuryAdmin,
            validationsAdmin,
            foundationAdmin,
            80,
            5,
            5,
            10,
            address(accessControl)
        );
    }

    ////////////
    // deploy //
    ////////////

    function test_deploy() public {
        vm.startPrank(address(1));
        address community = factory.deploy(
            "test",
            [
                factory.rewardsAdmin(),
                factory.treasuryAdmin(),
                factory.validationsAdmin(),
                factory.foundationAdmin()
            ],
            [
                factory.rewardsPercentage(),
                factory.treasuryPercentage(),
                factory.validationsPercentage(),
                factory.foundationPercentage()
            ],
            address(accessControl)
        );

        assertEq(ThriveProtocolCommunity(community).name(), "test");
    }

    function test_deploy_withoutRole() public {
        vm.startPrank(address(2));
        uint256 rewardsPercentage = factory.rewardsPercentage();
        uint256 treasuryPercentage = factory.treasuryPercentage();
        uint256 validationsPercentage = factory.validationsPercentage();
        uint256 foundationPercentage = factory.foundationPercentage();
        vm.expectRevert("ThriveProtocolCommunity: must have admin role");
        factory.deploy(
            "test",
            [rewardsAdmin, treasuryAdmin, validationsAdmin, foundationAdmin],
            [
                rewardsPercentage,
                treasuryPercentage,
                validationsPercentage,
                foundationPercentage
            ],
            address(accessControl)
        );
        vm.stopPrank();
        vm.prank(address(1));
        accessControl.grantRole(0x00, address(2));

        vm.startPrank(address(2));
        address community = factory.deploy(
            "test",
            [
                factory.rewardsAdmin(),
                factory.treasuryAdmin(),
                factory.validationsAdmin(),
                factory.foundationAdmin()
            ],
            [
                factory.rewardsPercentage(),
                factory.treasuryPercentage(),
                factory.validationsPercentage(),
                factory.foundationPercentage()
            ],
            address(accessControl)
        );
        vm.stopPrank();

        assertEq(ThriveProtocolCommunity(community).name(), "test");
    }

    /////////////
    // setters //
    /////////////

    function test_setRewardsAdmin() public {
        vm.prank(address(1));
        factory.setRewardsAdmin(address(6));
        assertEq(factory.rewardsAdmin(), address(6));
    }

    function test_setTreasuryAdmin() public {
        vm.prank(address(1));
        factory.setTreasuryAdmin(address(7));
        assertEq(factory.treasuryAdmin(), address(7));
    }

    function test_setValidationsAdmin() public {
        vm.prank(address(1));
        factory.setValidationsAdmin(address(8));
        assertEq(factory.validationsAdmin(), address(8));
    }

    function test_setFoundationAdmin() public {
        vm.prank(address(1));
        factory.setFoundationAdmin(address(9));
        assertEq(factory.foundationAdmin(), address(9));
    }

    function test_setRewardsAdmin_withoutRole() public {
        vm.prank(address(2));
        vm.expectRevert("ThriveProtocolCommunity: must have admin role");
        factory.setRewardsAdmin(address(6));

        vm.prank(address(1));
        accessControl.grantRole(0x00, address(2));
        vm.prank(address(2));
        factory.setRewardsAdmin(address(6));
        assertEq(factory.rewardsAdmin(), address(6));
    }

    function test_setTreasuryAdmin_withoutRole() public {
        vm.prank(address(2));
        vm.expectRevert("ThriveProtocolCommunity: must have admin role");
        factory.setTreasuryAdmin(address(7));

        vm.prank(address(1));
        accessControl.grantRole(0x00, address(2));
        vm.prank(address(2));
        factory.setTreasuryAdmin(address(7));
        assertEq(factory.treasuryAdmin(), address(7));
    }

    function test_setValidationsAdmin_withoutRole() public {
        vm.prank(address(2));
        vm.expectRevert("ThriveProtocolCommunity: must have admin role");
        factory.setValidationsAdmin(address(8));

        vm.prank(address(1));
        accessControl.grantRole(0x00, address(2));
        vm.prank(address(2));
        factory.setValidationsAdmin(address(8));
        assertEq(factory.validationsAdmin(), address(8));
    }

    function test_setFoundationAdmin_withoutRole() public {
        vm.prank(address(2));
        vm.expectRevert("ThriveProtocolCommunity: must have admin role");
        factory.setFoundationAdmin(address(9));

        vm.prank(address(1));
        accessControl.grantRole(0x00, address(2));
        vm.prank(address(2));
        factory.setFoundationAdmin(address(9));
        assertEq(factory.foundationAdmin(), address(9));
    }

    function test_setPercents() public {
        vm.prank(address(1));
        factory.setPercentage(90, 1, 1, 8);

        assertEq(factory.rewardsPercentage(), 90);
        assertEq(factory.treasuryPercentage(), 1);
        assertEq(factory.validationsPercentage(), 1);
        assertEq(factory.foundationPercentage(), 8);
    }

    function test_setPercents_withoutRole() public {
        vm.prank(address(2));
        vm.expectRevert("ThriveProtocolCommunity: must have admin role");
        factory.setPercentage(90, 1, 1, 8);

        vm.prank(address(1));
        accessControl.grantRole(0x00, address(2));
        vm.prank(address(2));
        factory.setPercentage(90, 1, 1, 8);
        assertEq(factory.rewardsPercentage(), 90);
    }

    function test_setAccessControl() public {
        MockAccessControl newAccessControl = new MockAccessControl();

        vm.prank(address(1));
        factory.setAccessControlEnumerable(address(newAccessControl));

        address accessAddress = address(factory.accessControlEnumerable());
        assertEq(accessAddress, address(newAccessControl));
    }

    function test_setAccessControl_withoutRole() public {
        MockAccessControl newAccessControl = new MockAccessControl();

        vm.startPrank(address(2));
        vm.expectRevert("ThriveProtocolCommunity: must have admin role");
        factory.setAccessControlEnumerable(address(newAccessControl));
    }

    /////////////
    // getters //
    /////////////

    function test_getAdmins() public view {
        assertEq(factory.rewardsAdmin(), rewardsAdmin);
        assertEq(factory.treasuryAdmin(), treasuryAdmin);
        assertEq(factory.validationsAdmin(), validationsAdmin);
        assertEq(factory.foundationAdmin(), foundationAdmin);
    }

    function test_getPercents() public view {
        assertEq(factory.rewardsPercentage(), 80);
        assertEq(factory.treasuryPercentage(), 5);
        assertEq(factory.validationsPercentage(), 5);
        assertEq(factory.foundationPercentage(), 10);
    }
}
