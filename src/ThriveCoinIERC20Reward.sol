// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ThriveCoinAdmins} from "./ThriveCoinAdmins.sol";

/**
 * @title ThriveCoinIERC20Reward
 * @notice Contract for managing rewards related to ThriveCoin
 */
contract ThriveCoinIERC20Reward is OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    ThriveCoinAdmins public thriveCoinAdmins;
    IERC20 public token;
    mapping(address => uint) public balanceOf;

    function initialize(
        address _thriveCoinAdmins,
        address _token
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        thriveCoinAdmins = ThriveCoinAdmins(_thriveCoinAdmins);
        token = IERC20(_token);
    }

    /**
     * @dev Overrides the authorization check for upgrading the contract implementation.
     * Only the owner of this contract can authorize upgrades.
     *
     * @param newImplementation The address of the new implementation contract.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
     * @dev Modifier to only allow execution by admins.
     * If the caller is not an admin, reverts with ThriveCoinAdmins.Not_An_Admin.
     */
    modifier onlyAdmin() {
        if (!thriveCoinAdmins.isAdmin(msg.sender)) {
            revert ThriveCoinAdmins.Not_An_Admin();
        }
        _;
    }

    /**
     * @dev Sets the ThriveCoinAdmins contract address.
     * Only the owner of this contract can call this function.
     *
     * @param _thriveCoinAdmins The address of the new ThriveCoinAdmins contract.
     */
    function setThriveCoinAdmins(address _thriveCoinAdmins) external onlyOwner {
        thriveCoinAdmins = ThriveCoinAdmins(_thriveCoinAdmins);
    }
}
