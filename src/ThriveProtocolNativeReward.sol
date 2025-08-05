// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import {OwnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlHelper} from "src/libraries/AccessControlHelper.sol";

/**
 * @title ThriveProtocolNativeReward
 * @notice Contract for managing rewards related to native token.
 * This contract allows admins to deposit tokens, give rewards, and users to withdraw their rewards.
 * It also allows admins to remove rewards when necessary.
 */
contract ThriveProtocolNativeReward is OwnableUpgradeable, UUPSUpgradeable {
    using AccessControlHelper for IAccessControlEnumerable;

    IAccessControlEnumerable public accessControlEnumerable;
    bytes32 public role;
    mapping(address => uint256) public balanceOf;

    /**
     * @dev Emitted when an admin rewards a user with tokens.
     */
    event Reward(address indexed recipient, uint256 amount, string reason);
    /**
     * @dev Emitted when an admin sends a reward directly to a user.
     */
    event RewardTransferred(
        address indexed recipient, uint256 amount, string reason
    );
    /**
     * @dev Emitted when a user withdraws tokens from the contract.
     */
    event Withdrawal(address indexed user, uint256 amount);
    /**
     * @dev Emitted when an admin removes a reward from a user.
     */
    event RewardRemoved(
        address indexed recipient, uint256 amount, string reason
    );

    /**
     * @dev Initializes the contract.
     * @param _accessControlEnumerable The address of the AccessControlEnumerable contract.
     * @param _role The access control role.
     */
    function initialize(address _accessControlEnumerable, bytes32 _role)
        public
        initializer
    {
        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();
        accessControlEnumerable =
            IAccessControlEnumerable(_accessControlEnumerable);
        role = _role;
    }

    /**
     * @dev Overrides the authorization check for upgrading the contract implementation.
     * Only the owner of this contract can authorize upgrades.
     *
     * @param newImplementation The address of the new implementation contract.
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    /**
     * @dev Modifier to only allow execution by admins.
     * If the caller is not an admin, reverts with a corresponding message
     */
    modifier onlyAdmin() {
        accessControlEnumerable.checkRole(role, msg.sender);
        _;
    }

    /**
     * @notice Deposit native tokens into the contract.
     * This function allows people to deposit native tokens into the contract.
     * The deposited tokens will be held in the contract's balance.
     */
    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than zero");
    }

    /**
     * @notice Allows depositing native tokens without data
     */
    receive() external payable {}

    /**
     * @notice Allows depositing native tokens with arbitrary data
     */
    fallback() external payable {}

    /**
     * @notice Withdraw native tokens from the contract.
     * This function allows users to withdraw their rewards from the contract.
     * Users can only withdraw rewards that they have earned.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdraw(uint256 _amount) external {
        require(balanceOf[_msgSender()] >= _amount, "Insufficient balance");
        require(
            address(this).balance >= _amount, "Insufficient contract balance"
        );

        balanceOf[_msgSender()] -= _amount;
        payable(_msgSender()).transfer(_amount);
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
     * @notice Sends a native token reward directly to a recipient's address.
     * @dev This function sends funds immediately, unlike the `reward` function which credits a balance for withdrawal.
     * The contract must have sufficient balance to cover the payout.
     * @param _recipient The address of the recipient.
     * @param _amount The amount of the reward to send.
     * @param _reason The reason for the reward.
     */
    function payoutReward(
        address payable _recipient,
        uint256 _amount,
        string calldata _reason
    ) external onlyAdmin {
        require(
            address(this).balance >= _amount,
            "ThriveProtocol: Insufficient contract balance"
        );

        emit RewardTransferred(_recipient, _amount, _reason);

        _transferNative(_recipient, _amount);
    }

    /**
     * @notice Sends native token rewards directly to multiple recipients in a single transaction.
     * @dev This function sends funds immediately. The contract must have sufficient balance to cover the total payout.
     * @param _recipients The addresses of the recipients.
     * @param _amounts The amounts of the rewards to send.
     * @param _reasons The reasons for the rewards.
     */
    function payoutRewardBulk(
        address payable[] calldata _recipients,
        uint256[] calldata _amounts,
        string[] calldata _reasons
    ) external onlyAdmin {
        require(
            _recipients.length == _amounts.length
                && _recipients.length == _reasons.length,
            "Array lengths mismatch"
        );

        uint256 totalPayout;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalPayout += _amounts[i];
        }

        require(
            address(this).balance >= totalPayout,
            "ThriveProtocol: Insufficient contract balance for bulk payout"
        );

        for (uint256 i = 0; i < _recipients.length; i++) {
            uint256 amount = _amounts[i];
            address payable recipient = _recipients[i];
            string calldata reason = _reasons[i];

            if (amount > 0) {
                emit RewardTransferred(recipient, amount, reason);

                _transferNative(recipient, amount);
            }
        }
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
            _recipients.length == _amounts.length
                && _recipients.length == _reasons.length,
            "Array lengths mismatch"
        );

        for (uint256 i = 0; i < _recipients.length; i++) {
            _reward(_recipients[i], _amounts[i], _reasons[i]);
        }
    }

    /**
     * @notice Removes a reward from a single recipient.
     * @dev This can be used to correct errors or claw back rewards.
     * The amount cannot exceed the recipient's current balance.
     * @param _recipient The address of the recipient.
     * @param _amount The amount to remove.
     * @param _reason The reason for removing the reward.
     */
    function removeReward(
        address _recipient,
        uint256 _amount,
        string calldata _reason
    ) external onlyAdmin {
        _removeReward(_recipient, _amount, _reason);
    }

    /**
     * @notice Removes rewards from multiple recipients in bulk.
     * @dev This can be used to correct errors or claw back rewards for multiple users at once.
     * The amounts cannot exceed the respective recipients' current balances.
     * @param _recipients The addresses of the recipients.
     * @param _amounts The amounts to remove.
     * @param _reasons The reasons for removing the rewards.
     */
    function removeRewardBulk(
        address[] calldata _recipients,
        uint256[] calldata _amounts,
        string[] calldata _reasons
    ) external onlyAdmin {
        require(
            _recipients.length == _amounts.length
                && _recipients.length == _reasons.length,
            "ThriveProtocol: array lengths mismatch!"
        );

        for (uint256 i = 0; i < _recipients.length; i++) {
            _removeReward(_recipients[i], _amounts[i], _reasons[i]);
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
     * @dev Internal function to remove a reward from a single recipient.
     * @param _recipient The address of the recipient.
     * @param _amount The amount to remove from the reward.
     * @param _reason The reason for the removal.
     */
    function _removeReward(
        address _recipient,
        uint256 _amount,
        string calldata _reason
    ) internal {
        require(
            balanceOf[_recipient] >= _amount,
            "ThriveProtocol: amount exceeds balance!"
        );
        balanceOf[_recipient] -= _amount;
        emit RewardRemoved(_recipient, _amount, _reason);
    }

    function _transferNative(address user, uint256 amount) internal {
        require(
            amount > 0,
            "ThriveProtocol: Payout amount must be greater than zero"
        );

        (bool success,) = user.call{value: amount}("");
        require(success, "ThriveProtocol: Native reward transfer failed");
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
        accessControlEnumerable =
            IAccessControlEnumerable(_accessControlEnumerable);
        role = _role;
    }
}
