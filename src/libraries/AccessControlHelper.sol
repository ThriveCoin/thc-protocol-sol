//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

library AccessControlHelper {
    bytes32 public constant ADMIN_ROLE = 0x00;

    function checkAdminRole(
        IAccessControlEnumerable accessControlEnumerable,
        address user
    ) internal view {
        require(
            accessControlEnumerable.hasRole(ADMIN_ROLE, user),
            "ThriveProtocolCommunity: must have admin role"
        );
    }
}
