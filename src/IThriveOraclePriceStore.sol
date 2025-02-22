// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IThriveOraclePriceStore {
    function getPrice(string calldata pair)
        external
        view
        returns (uint256, uint256, address);
}
