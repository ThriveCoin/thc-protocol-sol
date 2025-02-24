// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import {OwnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlHelper} from "src/libraries/AccessControlHelper.sol";
import {IThriveOraclePriceStore} from "src/IThriveOraclePriceStore.sol";

/**
 * @title OraclePriceStore
 * @notice Contract for storing and managing oracle prices with access control and upgradability.
 */
contract ThriveOraclePriceStore is
    OwnableUpgradeable,
    UUPSUpgradeable,
    IThriveOraclePriceStore
{
    using AccessControlHelper for IAccessControlEnumerable;

    IAccessControlEnumerable public accessControlEnumerable;
    bytes32 public role;

    struct PriceData {
        uint256 price;
        uint256 updatedAt;
        address updatedBy;
    }

    mapping(string => PriceData) public prices;
    uint256 public decimals;

    event PriceUpdated(
        string pair, uint256 price, uint256 updatedAt, address updatedBy
    );

    /**
     * @dev Initializes the contract.
     * @param _accessControlEnumerable The address of the AccessControlEnumerable contract.
     * @param _role The access control role.
     * @param _decimals Decimal precision of prices.
     */
    function initialize(
        address _accessControlEnumerable,
        bytes32 _role,
        uint256 _decimals
    ) public initializer {
        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();
        accessControlEnumerable =
            IAccessControlEnumerable(_accessControlEnumerable);
        role = _role;
        decimals = _decimals;
    }

    /**
     * @dev Overrides the authorization check for upgrading the contract implementation.
     * Only the owner of this contract can authorize upgrades.
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    /**
     * @dev Modifier to only allow execution by admins.
     */
    modifier onlyAdmin() {
        accessControlEnumerable.checkRole(role, msg.sender);
        _;
    }

    /**
     * @notice Updates the price of a pair.
     * @param _pair The pair identifier (e.g., ETH/USD).
     * @param _price The latest price of the pair.
     */
    function setPrice(string calldata _pair, uint256 _price)
        external
        onlyAdmin
    {
        prices[_pair] = PriceData({
            price: _price,
            updatedAt: block.timestamp,
            updatedBy: msg.sender
        });
        emit PriceUpdated(_pair, _price, block.timestamp, msg.sender);
    }

    /**
     * @notice Gets the price of a pair.
     * @param _pair The pair identifier.
     * @return The latest price of the pair.
     */
    function getPrice(string calldata _pair)
        external
        view
        returns (uint256, uint256, address)
    {
        PriceData memory data = prices[_pair];
        require(data.updatedAt != 0, "Price missing");
        return (data.price, data.updatedAt, data.updatedBy);
    }

    /**
     * @dev Sets the AccessControlEnumerable contract address.
     * Only the owner of this contract can call this function.
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
