// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import {OwnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from
    "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {AccessControlHelper} from "src/libraries/AccessControlHelper.sol";
import {IThriveIERC20Wrapper} from "src/IThriveIERC20Wrapper.sol";
import {SignatureHelper} from "src/libraries/SignatureHelper.sol";

contract ThriveBridgeDestination is
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuard
{
    using AccessControlHelper for IAccessControlEnumerable;

    event TokenMinted(
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        uint256 timestamp,
        uint256 nonce,
        bytes signature
    );

    event TokenBurned(
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        uint256 timestamp,
        uint256 nonce,
        bytes signature
    );

    address public srcContract;
    IAccessControlEnumerable public accessControlEnumerable;
    bytes32 public role;
    uint256 public supply;
    IThriveIERC20Wrapper public token;
    mapping(address => mapping(uint256 => bool)) public mintNonces;
    mapping(address => uint256) public burnNonces;

    function initialize(
        address _srcContract,
        address _accessControlEnumerable,
        bytes32 _role,
        address _token
    ) public initializer {
        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();

        srcContract = _srcContract;
        accessControlEnumerable =
            IAccessControlEnumerable(_accessControlEnumerable);
        role = _role;
        token = IThriveIERC20Wrapper(_token);
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

    function setSrcContract(address _srcContract) external onlyOwner {
        srcContract = _srcContract;
    }

    function mintTokens(
        address sender,
        address receiver,
        uint256 amount,
        uint256 nonce,
        bytes calldata signature
    ) external onlyAdmin nonReentrant {
        _mintTokens(sender, receiver, amount, nonce, signature);
    }

    function _mintTokens(
        address sender,
        address receiver,
        uint256 amount,
        uint256 nonce,
        bytes calldata signature
    ) internal virtual {
        require(amount > 0, "ThriveProtocol: amount must be greater than zero");

        require(
            !mintNonces[sender][nonce],
            "ThriveProtocol: request already processed"
        );
        mintNonces[sender][nonce] = true;

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            srcContract, sender, receiver, nonce, amount
        );
        bool validSignature =
            SignatureHelper.verifyBridgeRequest(sender, hash, signature);
        require(validSignature, "ThriveProtocol: invalid signature");

        supply += amount;

        emit TokenMinted(
            sender, receiver, amount, block.timestamp, nonce, signature
        );

        token.mint(receiver, amount);
    }

    function burnTokens(
        address receiver,
        uint256 amount,
        bytes calldata signature
    ) external nonReentrant {
        _burnTokens(_msgSender(), receiver, amount, signature);
    }

    function _burnTokens(
        address sender,
        address receiver,
        uint256 amount,
        bytes calldata signature
    ) internal virtual {
        require(amount > 0, "ThriveProtocol: amount must be greater than zero");

        uint256 nonce = burnNonces[sender];
        burnNonces[sender]++;

        bytes32 hash = SignatureHelper.hashBridgeRequest(
            address(this), sender, receiver, nonce, amount
        );
        bool validSignature =
            SignatureHelper.verifyBridgeRequest(sender, hash, signature);
        require(validSignature, "ThriveProtocol: invalid signature");

        supply -= amount;

        emit TokenBurned(
            sender, receiver, amount, block.timestamp, nonce, signature
        );

        token.burnFrom(sender, amount);
    }
}
