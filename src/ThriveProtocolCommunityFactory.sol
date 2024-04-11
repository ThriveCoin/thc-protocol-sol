//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ThriveProtocolCommunity} from "src/ThriveProtocolCommunity.sol";

contract ThriveProtocolCommunityFactory {
    /**
     * @notice Deploy the community contract
     * can calls only user with DEFAULT_ADMIN role
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
    ) external returns (address) {
        ThriveProtocolCommunity community = new ThriveProtocolCommunity(
            msg.sender,
            _name,
            _admins,
            _percentages,
            _accessControlEnumerable,
            _role
        );

        return address(community);
    }
}
