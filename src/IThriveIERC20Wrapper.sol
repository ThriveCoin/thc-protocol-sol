// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IThriveIERC20Wrapper is IERC20 {
    function mint(address recipient, uint256 amount) external;
    function burn(uint256 value) external;
    function burnFrom(address account, uint256 value) external;
}
