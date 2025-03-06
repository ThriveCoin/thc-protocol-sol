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
    event Withdrawn(address indexed user, uint256 principal, uint256 yield);
    event YieldClaimed(address indexed user, uint256 yield);

    struct StakingDetails {
        uint256 firstHalfAmount; // Stake deposited in the first half of the epoch
        uint256 secondHalfAmount; // Stake deposited in the second half of the epoch
        uint256 epoch; // The epoch index (starting at 0) in which the stake was made
    }

    // Yield rate is assumed to be the full-epoch yield (scaled by 1e18).
    // For example, a yieldRate of 0.1e18 (i.e. 10% per epoch) will yield 10% on full-epoch stakes,
    // and 5% for stakes made after the half-epoch mark.
    uint256 public yieldRate;
    uint256 public minStakingAmount;

    // Global epoch configuration:
    uint256 public epochStart; // timestamp marking the start of epoch 0
    uint256 public constant EPOCH_DURATION = 30 days;
    uint256 public constant HALF_EPOCH_DURATION = 15 days;

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

        epochStart = block.timestamp;
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

    /**
     * @dev Returns the current epoch index.
     * Epoch index 0 means: block.timestamp is in [epochStart, epochStart + EPOCH_DURATION).
     */
    function currentEpoch() public view returns (uint256) {
        return (block.timestamp - epochStart) / EPOCH_DURATION;
    }

    /**
     * @notice Calculates the yield for a staker based on their stake in the epoch.
     * Yield is only claimable if the epoch in which the stake was made is over.
     * For stakes deposited in the first half, the full yieldRate applies; for stakes in the second half,
     * only half yield is awarded.
     * @param staker The address of the staker.
     * @return yieldAmount The total yield earned.
     */
    function calculateYield(address staker) public view returns (uint256 yieldAmount) {
        StakingDetails memory details = stakers[staker];
        if (currentEpoch() <= details.epoch) {
            return 0;
        }
        uint256 yieldFull = (details.firstHalfAmount * yieldRate) / 1e18;
        uint256 yieldHalf = (details.secondHalfAmount * yieldRate) / (2 * 1e18);

        return yieldFull + yieldHalf;
    }

    /**
     * @notice Withdraws the staked principal and any yield if the epoch has ended.
     * If called before the end of the epoch, the yield is forfeited.
     */
    function withdraw() external nonReentrant {
        StakingDetails storage details = stakers[msg.sender];
        uint256 totalStaked = details.firstHalfAmount + details.secondHalfAmount;
        require(totalStaked >= minStakingAmount, "ThriveProtocol: stake below minimum");
        require(totalStaked > 0, "ThriveProtocol: no staked tokens");

        uint256 yieldAmount = 0;
        if (currentEpoch() > details.epoch) {
            yieldAmount = calculateYield(msg.sender);
        }
        uint256 totalAmount = totalStaked + yieldAmount;

        details.firstHalfAmount = 0;
        details.secondHalfAmount = 0;
        details.epoch = 0;

        _transferYield(msg.sender, totalAmount);
        emit Withdrawn(msg.sender, totalStaked, yieldAmount);
    }

    /**
     * @notice Claims the yield for a finished epoch while leaving the staked principal intact.
     * The principal is “rolled over” to the new epoch as if it were staked at the start.
     */
    function claimYield() external nonReentrant {
        StakingDetails storage details = stakers[msg.sender];
        uint256 totalStaked = details.firstHalfAmount + details.secondHalfAmount;
        require(totalStaked > 0, "ThriveProtocol: no staked tokens");
        require(totalStaked >= minStakingAmount, "ThriveProtocol: stake below minimum");
        require(currentEpoch() > details.epoch, "ThriveProtocol: epoch not finished");

        uint256 yieldAmount = calculateYield(msg.sender);
        require(yieldAmount > 0, "ThriveProtocol: no yield to claim");

        _transferYield(msg.sender, yieldAmount);
        emit YieldClaimed(msg.sender, yieldAmount);

        details.epoch = currentEpoch();
        details.firstHalfAmount = totalStaked;
        details.secondHalfAmount = 0;
    }

    /**
     * @notice External stake function.
     * If a user already has a stake for an epoch, they must finalize (withdraw or claim yield)
     * before adding more funds in a new epoch.
     */
    function stake(uint256 amount) external payable nonReentrant {
        _stake(amount);
    }

    /**
     * @dev Internal stake function.
     * Enforces the minimum stake amount. Determines whether the funds are added to the first or
     * second half of the current epoch. (If a previous epoch’s stake exists, it must be finalized first.)
     */
    function _stake(uint256 amount) internal virtual {
        uint256 epochIndex = currentEpoch();
        StakingDetails storage details = stakers[msg.sender];
        uint256 currentTotal = details.firstHalfAmount + details.secondHalfAmount;
        require(currentTotal == 0 || details.epoch == epochIndex, "ThriveProtocol: finalize previous epoch first");

        uint256 epochPhaseStart = epochStart + (epochIndex * EPOCH_DURATION);
        if (block.timestamp < epochPhaseStart + HALF_EPOCH_DURATION) {
            details.firstHalfAmount += amount;
        } else {
            details.secondHalfAmount += amount;
        }
        details.epoch = epochIndex;

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Returns the total staked amount for a user.
     */
    function getStakedAmount(address user) external view returns (uint256) {
        StakingDetails memory details = stakers[user];
        return details.firstHalfAmount + details.secondHalfAmount;
    }

    /**
     * @notice Returns the timestamp when the current epoch (for the user's stake) ends.
     */
    function getEpochEndTimestamp(address user) external view returns (uint256) {
        StakingDetails memory details = stakers[user];
        require(details.firstHalfAmount + details.secondHalfAmount > 0, "ThriveProtocol: no staked tokens");
        uint256 epochIndex = details.epoch;
        return epochStart + ((epochIndex + 1) * EPOCH_DURATION);
    }

    /// @dev Token-specific yield transfer function to be implemented in derived contracts.
    function _transferYield(address user, uint256 amount) internal virtual;
}
