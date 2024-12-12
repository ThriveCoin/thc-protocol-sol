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

abstract contract ThriveBridgeSourceBase is
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuard
{
    using AccessControlHelper for IAccessControlEnumerable;

    event TokenLocked(
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        uint256 timestamp,
        uint256 nonce,
        bytes signature
    );

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

    function _initialize(
        address _destContract,
        address _accessControlEnumerable,
        bytes32 _role
    ) internal virtual {
        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();

        destContract = _destContract;
        accessControlEnumerable =
            IAccessControlEnumerable(_accessControlEnumerable);
        role = _role;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    modifier onlyAdmin() {
        accessControlEnumerable.checkRole(role, _msgSender());
        _;
    }

    function setAccessControlEnumerable(
        address _accessControlEnumerable,
        bytes32 _role
    ) external onlyOwner {
        accessControlEnumerable =
            IAccessControlEnumerable(_accessControlEnumerable);
        role = _role;
    }

    function setDestContract(address _destContract) external onlyOwner {
        destContract = _destContract;
    }

    function lockTokens(
        address receiver,
        uint256 amount,
        bytes calldata signature
    ) external payable nonReentrant {
        _lockTokens(_msgSender(), receiver, amount, signature);
    }

    function _lockTokens(
        address sender,
        address receiver,
        uint256 amount,
        bytes calldata signature
    ) internal virtual {
        require(amount > 0, "ThriveProtocol: amount must be greater than zero");

        uint256 nonce = lockNonces[sender];
        lockNonces[sender]++;

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(this), sender, receiver, nonce, amount
        );
        bool validSignature =
            SignatureHelper.verifyBridgeRequest(sender, hash, signature);
        require(validSignature, "ThriveProtocol: invalid signature");

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
    ) external onlyAdmin nonReentrant {
        _unlockTokens(sender, receiver, amount, nonce, signature);
    }

    function _unlockTokens(
        address sender,
        address receiver,
        uint256 amount,
        uint256 nonce,
        bytes calldata signature
    ) internal virtual {
        require(amount > 0, "ThriveProtocol: amount must be greater than zero");

        require(
            !unlockNonces[sender][nonce],
            "ThriveProtocol: request already processed"
        );
        unlockNonces[sender][nonce] = true;

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            destContract, sender, receiver, nonce, amount
        );
        bool validSignature =
            SignatureHelper.verifyBridgeRequest(sender, hash, signature);
        require(validSignature, "ThriveProtocol: invalid signature");

        supply -= amount;

        emit TokenUnlocked(
            sender, receiver, amount, block.timestamp, nonce, signature
        );
    }
}
