// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import {ReentrancyGuard} from
    "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AccessControlHelper} from "src/libraries/AccessControlHelper.sol";

/*
* @title ThriveStakingBase.sol
* @dev Core contract for staking opportunities in various communities.
*
*
$$$$$$$$\ $$\                 $$\                       $$$$$$\    $$\               $$\       $$\                     
\__$$  __|$$ |                \__|                     $$  __$$\   $$ |              $$ |      \__|                    
   $$ |   $$$$$$$\   $$$$$$\  $$\ $$\    $$\  $$$$$$\  $$ /  \__|$$$$$$\    $$$$$$\  $$ |  $$\ $$\ $$$$$$$\   $$$$$$\  
   $$ |   $$  __$$\ $$  __$$\ $$ |\$$\  $$  |$$  __$$\ \$$$$$$\  \_$$  _|   \____$$\ $$ | $$  |$$ |$$  __$$\ $$  __$$\ 
   $$ |   $$ |  $$ |$$ |  \__|$$ | \$$\$$  / $$$$$$$$ | \____$$\   $$ |     $$$$$$$ |$$$$$$  / $$ |$$ |  $$ |$$ /  $$ |
   $$ |   $$ |  $$ |$$ |      $$ |  \$$$  /  $$   ____|$$\   $$ |  $$ |$$\ $$  __$$ |$$  _$$<  $$ |$$ |  $$ |$$ |  $$ |
   $$ |   $$ |  $$ |$$ |      $$ |   \$  /   \$$$$$$$\ \$$$$$$  |  \$$$$  |\$$$$$$$ |$$ | \$$\ $$ |$$ |  $$ |\$$$$$$$ |
   \__|   \__|  \__|\__|      \__|    \_/     \_______| \______/    \____/  \_______|\__|  \__|\__|\__|  \__| \____$$ |
                                                                                                             $$\   $$ |
                                                                                                             \$$$$$$  |
                                                                                                              \______/ 
                                                                                                                       
*
*/

abstract contract ThriveStakingBase is
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuard
{
    using AccessControlHelper for IAccessControlEnumerable;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, uint256 yield);
    event YieldClaimed(address indexed user, uint256 yield);

    struct StakingDetails {
        uint256 amount;
        uint256 stakingTime;
        uint256 lastYieldTime;
    }

    uint256 public yieldRate;
    uint256 public minStakingAmount;
    uint256 public constant MIN_STAKING_PERIOD = 30 days;

    // For ERC20 staking, token != address(0); for native staking, token == address(0)
    address public token;
    IAccessControlEnumerable public accessControlEnumerable;
    bytes32 public adminRole;

    mapping(address => StakingDetails) public stakers;

    function _initialize(
        address _token,
        uint256 _yieldRate,
        uint256 _minStakingAmount,
        address _accessControlEnumerable,
        bytes32 _role
    ) internal virtual {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        yieldRate = _yieldRate;
        minStakingAmount = _minStakingAmount;
        token = _token;
        accessControlEnumerable =
            IAccessControlEnumerable(_accessControlEnumerable);
        adminRole = _role;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    modifier onlyAdmin() {
        accessControlEnumerable.checkRole(adminRole, _msgSender());
        _;
    }

    function setAccessControlEnumerable(
        address _accessControlEnumerable,
        bytes32 _role
    ) external onlyOwner {
        accessControlEnumerable =
            IAccessControlEnumerable(_accessControlEnumerable);
        adminRole = _role;
    }

    function setYieldRate(uint256 _yieldRate) external onlyAdmin {
        yieldRate = _yieldRate;
    }

    function setMinStakingAmount(uint256 _minStakingAmount)
        external
        onlyAdmin
    {
        minStakingAmount = _minStakingAmount;
    }

    /// @notice Calculates staking yield based on the amount staked and duration since the last yield claim.
    function calculateYield(address staker) public view returns (uint256) {
        StakingDetails memory details = stakers[staker];
        uint256 stakedDuration = block.timestamp - details.lastYieldTime;

        uint256 decimals =
            token == address(0) ? 18 : IERC20Metadata(token).decimals();
        return (details.amount * yieldRate * stakedDuration) / (10 ** decimals);
    }

    /// @notice Claims only the staking yield.
    function claimYield() external nonReentrant {
        StakingDetails storage details = stakers[msg.sender];
        require(details.amount > 0, "ThriveProtocol: no staked tokens");

        uint256 yield = calculateYield(msg.sender);
        require(yield > 0, "ThriveProtocol: no yield to claim");

        details.lastYieldTime = block.timestamp; // Reset yield calculation start point

        _transferYield(msg.sender, yield);
        emit YieldClaimed(msg.sender, yield);
    }

    /// @notice Unstakes the full staked amount, transfers it along with pending yields, and resets the staking details.
    function withdraw() external nonReentrant {
        StakingDetails storage details = stakers[msg.sender];
        require(details.amount > 0, "ThriveProtocol: no staked tokens");
        require(
            block.timestamp >= details.stakingTime + MIN_STAKING_PERIOD,
            "ThriveProtocol: 30-day lockup"
        );

        uint256 yield = calculateYield(msg.sender);
        uint256 totalAmount = details.amount + yield;

        _transferYield(msg.sender, totalAmount);

        emit Withdrawn(msg.sender, details.amount, yield);

        details.amount = 0;
        details.stakingTime = 0;
        details.lastYieldTime = 0;
    }

    /// @notice External stake function that calls the internal _stake; can be overridden.
    function stake(uint256 amount) external payable nonReentrant {
        _stake(amount);
    }

    /// @dev Common internal function to update staking details and emit the Staked event.
    function _stake(uint256 amount) internal virtual {
        uint256 pendingYield = calculateYield(msg.sender);
        require(
            pendingYield == 0,
            "ThriveProtocol: claim yield first and retry stake again"
        );

        StakingDetails storage details = stakers[msg.sender];
        details.amount += amount;
        details.stakingTime = block.timestamp;
        details.lastYieldTime = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    /// @dev Token-specific yield transfer function to be implemented in derived contracts.
    function _transferYield(address user, uint256 amount) internal virtual;
}
