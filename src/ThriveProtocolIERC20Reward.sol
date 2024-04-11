// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControlHelper} from "src/libraries/AccessControlHelper.sol";

/**
 * @title ThriveProtocolIERC20Reward
 * @notice Contract for managing rewards related to ERC20 token.
 * This contract allows admins to deposit tokens, give rewards, and users to withdraw their rewards.
 */
contract ThriveProtocolIERC20Reward is OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;
    using AccessControlHelper for IAccessControlEnumerable;

    IAccessControlEnumerable public accessControlEnumerable;
    IERC20 public token;
    bytes32 public role;
    mapping(address => uint256) public balanceOf;

    /**
     * @dev Emitted when an admin rewads a user with tokens.
     */
    event Reward(address indexed recipient, uint256 amount, string reason);
    /**
     * @dev Emitted when a user withdraws tokens from the contract.
     */
    event Withdrawal(address indexed user, uint256 amount);

    /**
     * @dev Initializes the contract.
     * @param _accessControlEnumerable The address of the AccessControlEnumerable contract.
     * @param _role The access control role.
     * @param _token The address of ERC20 token contract.
     */
    function initialize(
        address _accessControlEnumerable,
        bytes32 _role,
        address _token
    ) public initializer {
        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();
        accessControlEnumerable = IAccessControlEnumerable(
            _accessControlEnumerable
        );
        token = IERC20(_token);
        role = _role;
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
     * If the caller is not an admin, reverts with a corresponding message
     */
    modifier onlyAdmin() {
        accessControlEnumerable.checkRole(role, msg.sender);
        _;
    }

    /**
     * @notice Deposit tokens into the contract.
     * This function allows people to deposit tokens into the contract.
     * The deposited tokens will be held in the contract's balance.
     * @param _amount The amount of tokens to deposit.
     */
    function deposit(uint256 _amount) external {
        token.safeTransferFrom(_msgSender(), address(this), _amount);
    }

    /**
     * @notice Withdraw tokens from the contract.
     * This function allows users to withdraw their rewards from the contract.
     * Users can only withdraw rewards that they have earned.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdraw(uint256 _amount) external {
        require(balanceOf[_msgSender()] >= _amount, "Insufficient balance");
        require(
            token.balanceOf(address(this)) >= _amount,
            "Insufficient contract balance"
        );

        balanceOf[_msgSender()] -= _amount;
        token.safeTransfer(_msgSender(), _amount);
        emit Withdrawal(_msgSender(), _amount);
    }

    /**
     * @dev Give a reward to a single recipient.
     * @param _recipient The address of the recipient.
     * @param _amount The amount of the reward.
     * @param _reason The reason for the reward.
     */
    function reward(
        address _recipient,
        uint256 _amount,
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
        uint256[] calldata _amounts,
        string[] calldata _reasons
    ) external onlyAdmin {
        require(
            _recipients.length == _amounts.length &&
                _recipients.length == _reasons.length,
            "Array lengths mismatch"
        );

        for (uint256 i = 0; i < _recipients.length; i++) {
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
        uint256 _amount,
        string calldata _reason
    ) internal {
        balanceOf[_recipient] += _amount;
        emit Reward(_recipient, _amount, _reason);
    }

    /**
     * @dev Sets the AccessControlEnumerable contract address.
     * Only the owner of this contract can call this function.
     *
     * @param _accessControlEnumerable The address of the new AccessControlEnumerable contract.
     * @param _role The new access control role.
     */
    function setAccessControlEnumerable(
        address _accessControlEnumerable,
        bytes32 _role
    ) external onlyOwner {
        accessControlEnumerable = IAccessControlEnumerable(
            _accessControlEnumerable
        );
        role = _role;
    }
}
