// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ThriveCoinAdmins} from "./ThriveCoinAdmins.sol";

/**
 * @title ThriveCoinIERC20Reward
 * @notice Contract for managing rewards related to ERC20 token.
 * This contract allows admins to deposit tokens, give rewards, and users to withdraw their rewards.
 */
contract ThriveCoinIERC20Reward is OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    ThriveCoinAdmins public thriveCoinAdmins;
    IERC20 public token;
    mapping(address => uint256) public balanceOf;

    /**
     * @dev Emitted when an admin rewads a user with tokens.
     */
    event Reward(address indexed recipient, uint amount, string reason);
    /**
     * @dev Emitted when a user withdraws tokens from the contract.
     */
    event Withdrawal(address indexed user, uint amount);

    /**
     * @dev Initializes the contract.
     * @param _thriveCoinAdmins The address of the ThriveCoinAdmins contract.
     * @param _token The address of ERC20 token contract.
     */
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
     * @notice Deposit tokens into the contract.
     * This function allows people to deposit tokens into the contract.
     * The deposited tokens will be held in the contract's balance.
     * @param _amount The amount of tokens to deposit.
     */
    function deposit(uint _amount) external {
        token.safeTransferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @notice Withdraw tokens from the contract.
     * This function allows users to withdraw their rewards from the contract.
     * Users can only withdraw rewards that they have earned.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdraw(uint _amount) external {
        require(balanceOf[msg.sender] >= _amount, "Insufficient balance");
        require(
            token.balanceOf(address(this)) >= _amount,
            "Insufficient contract balance"
        );

        balanceOf[msg.sender] -= _amount;
        token.safeTransfer(msg.sender, _amount);
        emit Withdrawal(msg.sender, _amount);
    }

    /**
     * @dev Give a reward to a single recipient.
     * @param _recipient The address of the recipient.
     * @param _amount The amount of the reward.
     * @param _reason The reason for the reward.
     */
    function reward(
        address _recipient,
        uint _amount,
        string calldata _reason
    ) external onlyAdmin {
        _reward(_recipient, _amount, _reason);
    }

    /**
     * @dev Give rewards to multiple recipients in bulk.
     * @param _recipients The addresses of the recipients.
     * @param _amounts The amounts of the rewards.
     * @param _reasons The reasons for the rewards.
     */
    function rewardBulk(
        address[] calldata _recipients,
        uint[] calldata _amounts,
        string[] calldata _reasons
    ) external onlyAdmin {
        require(
            _recipients.length == _amounts.length &&
                _recipients.length == _reasons.length,
            "Array lengths mismatch"
        );

        for (uint i = 0; i < _recipients.length; i++) {
            _reward(_recipients[i], _amounts[i], _reasons[i]);
        }
    }

    /**
     * @dev Internal function to give a reward to a single recipient.
     * @param _recipient The address of the recipient.
     * @param _amount The amount of the reward.
     * @param _reason The reason for the reward.
     */
    function _reward(
        address _recipient,
        uint _amount,
        string calldata _reason
    ) private {
        balanceOf[_recipient] += _amount;
        emit Reward(_recipient, _amount, _reason);
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
