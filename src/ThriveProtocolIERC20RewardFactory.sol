//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ThriveProtocolIERC20Reward} from "src/ThriveProtocolIERC20Reward.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ThriveProtocolIERC20RewardFactory is
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

    function deploy(
        address _accessControlEnumerable,
        bytes32 _role,
        address _token
    ) external returns (address, address) {
        ThriveProtocolIERC20Reward implementation =
            new ThriveProtocolIERC20Reward();
        address implAddress = address(implementation);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");

        implementation = ThriveProtocolIERC20Reward(address(proxy));
        implementation.initialize(_accessControlEnumerable, _role, _token);
        return (implAddress, address(proxy));
    }
}
