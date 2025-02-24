// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IThriveComplianceStore} from "src/IThriveComplianceStore.sol";
import {IThriveIERC20Wrapper} from "src/IThriveIERC20Wrapper.sol";
import {IThriveOraclePriceStore} from "src/IThriveOraclePriceStore.sol";
import {ThriveBridgeDestination} from "src/ThriveBridgeDestination.sol";

/**
 * @title ThriveBridgeDestinationWithCompliance
 * @notice Extends ThriveBridgeDestination by adding compliance verification.
 * It integrates compliance checks before token burning.
 */
contract ThriveBridgeDestinationWithCompliance is ThriveBridgeDestination {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @notice Trading pair (e.g., ETH-USDT)
    string public pair;
    /// @notice Reference to the price store contract
    IThriveOraclePriceStore public priceStore;
    /// @notice Reference to the compliance store contract
    IThriveComplianceStore public complianceStore;

    /// @notice Stores compliance rules with checkType as key and price limit as value
    mapping(bytes32 => uint256) public complianceRules;
    /// @notice Set of compliance check types for efficient iteration
    EnumerableSet.Bytes32Set internal complianceCheckTypes;

    /**
     * @dev Initializes the contract.
     * @param _srcContract The address of the source contract.
     * @param _accessControlEnumerable The address of the access control contract.
     * @param _role The role required for administrative actions.
     * @param _token The address of the token contract.
     * @param _pair The trading pair associated with the bridge.
     * @param _priceStore The address of the price store contract.
     * @param _complianceStore The address of the compliance store contract.
     */
    function initialize(
        address _srcContract,
        address _accessControlEnumerable,
        bytes32 _role,
        address _token,
        string calldata _pair,
        address _priceStore,
        address _complianceStore
    ) public initializer {
        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();

        srcContract = _srcContract;
        accessControlEnumerable =
            IAccessControlEnumerable(_accessControlEnumerable);
        role = _role;
        token = IThriveIERC20Wrapper(_token);
        pair = _pair;
        priceStore = IThriveOraclePriceStore(_priceStore);
        complianceStore = IThriveComplianceStore(_complianceStore);
    }

    /**
     * @notice Sets the price store contract address.
     * @param _priceStore The new price store contract address.
     */
    function setPriceStore(address _priceStore) external onlyOwner {
        priceStore = IThriveOraclePriceStore(_priceStore);
    }

    /**
     * @notice Sets the compliance store contract address.
     * @param _complianceStore The new compliance store contract address.
     */
    function setComplianceStore(address _complianceStore) external onlyOwner {
        complianceStore = IThriveComplianceStore(_complianceStore);
    }

    /**
     * @notice Adds or updates a compliance rule.
     * @param checkType The identifier of the compliance check.
     * @param limit The price limit at which the compliance check is required.
     * Limits are in same unit as price store always!
     */
    function setComplianceRule(bytes32 checkType, uint256 limit)
        external
        onlyAdmin
    {
        require(limit > 0, "Limit must be greater than 0");
        complianceRules[checkType] = limit;
        complianceCheckTypes.add(checkType);
    }

    /**
     * @notice Removes a compliance rule.
     * @param checkType The identifier of the compliance check to be removed.
     */
    function removeComplianceRule(bytes32 checkType) external onlyAdmin {
        require(complianceCheckTypes.remove(checkType), "Rule does not exist");
        delete complianceRules[checkType];
    }

    /**
     * @dev Returns one of the compliance rules. `index` must be a value between
     * 0 and {getRoleMemberCount}, non-inclusive. Compliance rules are not
     * sorted in any particular way, and their ordering may change at any point.
     */
    function getComplianceRule(uint256 index)
        external
        view
        returns (bytes32, uint256)
    {
        bytes32 checkType = complianceCheckTypes.at(index);
        return (checkType, complianceRules[checkType]);
    }

    /**
     * @dev Returns the number of compliance rules. Can be used together with
     * {getComplianceRule} to enumerate all rules.
     */
    function getComplianceRuleCount() external view returns (uint256) {
        return complianceCheckTypes.length();
    }

    /**
     * @dev Internal function to burn tokens while enforcing compliance rules.
     * @param sender The address initiating the token burn.
     * @param receiver The recipient address on the destination chain.
     * @param amount The amount of tokens to be burned.
     * @param signature The signature for verification.
     */
    function _burnTokens(
        address sender,
        address receiver,
        uint256 amount,
        bytes calldata signature
    ) internal virtual override {
        uint256 tokenDecimals = token.decimals();
        (uint256 price,,) = priceStore.getPrice(pair);

        for (uint256 i = 0; i < complianceCheckTypes.length(); i++) {
            bytes32 checkType = complianceCheckTypes.at(i);
            if (
                amount * price / 10 ** tokenDecimals
                    >= complianceRules[checkType]
            ) {
                require(
                    complianceStore.passedComplianceCheck(checkType, sender),
                    "Compliance check failed"
                );
            }
        }

        super._burnTokens(sender, receiver, amount, signature);
    }
}
