//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ThriveProtocolAccessControl} from "src/ThriveProtocolAccessControl.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ThriveProtocolAccessControlFactory is OwnableUpgradeable, UUPSUpgradeable {
    function initialize() public initializer {
        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    /**
     * @notice Deploy the AccessControl contract
     */
    function deploy() external returns (address, address) {
        ThriveProtocolAccessControl implementation = new ThriveProtocolAccessControl();
        address implAddress = address(implementation);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");

        implementation = ThriveProtocolAccessControl(address(proxy));
        implementation.initialize();
        return (implAddress, address(proxy));
    }
}
