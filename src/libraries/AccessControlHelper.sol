//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

library AccessControlHelper {
    function checkAdminRole(
        AccessControlEnumerable accessControlEnumerable,
        address user
    ) internal view {
        require(
            accessControlEnumerable.hasRole(
                accessControlEnumerable.DEFAULT_ADMIN_ROLE(), user
            ),
            "ThriveProtocolCommunity: must have admin role"
        );
    }
}
