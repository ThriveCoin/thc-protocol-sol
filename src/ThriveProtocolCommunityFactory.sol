//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ThriveProtocolCommunity} from "src/ThriveProtocolCommunity.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ThriveProtocolCommunityFactory is
    OwnableUpgradeable,
    UUPSUpgradeable
{
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
     * @notice Deploy the community contract
     * @param _name The name of the community
     * @param _admins The array with addresses of admins
     * @param _percentages The array with value of percents for distribution
     * @param _accessControlEnumerable The address of access control enumerable contract
     * @return The address of deployed comminity contract
     */
    function deploy(
        string memory _name,
        address[4] memory _admins,
        uint256[4] memory _percentages,
        address _accessControlEnumerable,
        bytes32 _role
    ) external returns (address, address) {
        ThriveProtocolCommunity implementation = new ThriveProtocolCommunity();
        address implAddress = address(implementation);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");

        implementation = ThriveProtocolCommunity(address(proxy));
        implementation.initialize(
            _name, _admins, _percentages, _accessControlEnumerable, _role
        );
        return (implAddress, address(proxy));
    }
}
