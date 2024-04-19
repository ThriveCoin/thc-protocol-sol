//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";

library AccessControlHelper {
    function checkRole(
        IAccessControlEnumerable accessControlEnumerable,
        bytes32 role,
        address user
    ) internal view {
        require(
            accessControlEnumerable.hasRole(role, user),
            "ThriveProtocol: must have admin role"
        );
    }
}
