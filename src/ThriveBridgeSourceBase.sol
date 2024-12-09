// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import {OwnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuard} from
    "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {AccessControlHelper} from "src/libraries/AccessControlHelper.sol";
import {SignatureHelper} from "src/libraries/SignatureHelper.sol";

/**
 * @title ThriveBridgeSourceERC20
 * @notice This contract manages...
 */
contract ThriveBridgeSourceBase is
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuard
{
    using AccessControlHelper for IAccessControlEnumerable;

    /**
     * @dev Emitted when an admin rewads a user with tokens.
     */
    event TokenLocked(
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        uint256 timestamp,
        uint256 nonce,
        bytes signature
    );

    /**
     * @dev Emitted when an admin rewads a user with tokens.
     */
    event TokenUnlocked(
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        uint256 timestamp,
        uint256 nonce,
        bytes signature
    );

    address public destContract;
    IAccessControlEnumerable public accessControlEnumerable;
    bytes32 public role;
    uint256 public supply;
    mapping(address => uint256) public lockNonces;
    mapping(address => mapping(uint256 => bool)) public unlockNonces;

    /**
     * @dev Initializes the contract.
     * @param _accessControlEnumerable The address of the AccessControlEnumerable contract.
     * @param _role The access control role.
     */
    function initialize(
        address _destContract,
        address _accessControlEnumerable,
        bytes32 _role
    ) public initializer {
        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();

        destContract = _destContract;
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
        accessControlEnumerable.checkRole(role, _msgSender());
        _;
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

    function lockTokens(
        address receiver,
        uint256 amount,
        bytes calldata signature
    ) external payable {
        _lockTokens(_msgSender(), receiver, amount, signature);
    }

    function _lockTokens(
        address sender,
        address receiver,
        uint256 amount,
        bytes calldata signature
    ) internal virtual nonReentrant {
        require(amount > 0, "ThriveProtocol: amount must be greater than zero");

        uint256 nonce = lockNonces[sender];
        lockNonces[sender]++;

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            destContract, sender, receiver, nonce, amount
        );
        bool validSig =
            SignatureHelper.verifyBridgeRequest(sender, hash, signature);
        require(validSig, "ThriveProtocol: invalid signature");

        supply += amount;

        emit TokenLocked(
            sender, receiver, amount, block.timestamp, nonce, signature
        );
    }

    function unlockTokens(
        address sender,
        address receiver,
        uint256 amount,
        uint256 nonce,
        bytes calldata signature
    ) external onlyAdmin {
        _unlockTokens(sender, receiver, amount, nonce, signature);
    }

    function _unlockTokens(
        address sender,
        address receiver,
        uint256 amount,
        uint256 nonce,
        bytes calldata signature
    ) internal virtual nonReentrant {
        require(amount > 0, "ThriveProtocol: amount must be greater than zero");

        require(
            !unlockNonces[sender][nonce],
            "ThriveProtocol: request already processed"
        );
        unlockNonces[sender][nonce] = true;

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(this), sender, receiver, nonce, amount
        );
        bool validSig =
            SignatureHelper.verifyBridgeRequest(sender, hash, signature);
        require(validSig, "ThriveProtocol: invalid signature");

        supply -= amount;

        emit TokenUnlocked(
            sender, receiver, amount, block.timestamp, nonce, signature
        );
    }
}
