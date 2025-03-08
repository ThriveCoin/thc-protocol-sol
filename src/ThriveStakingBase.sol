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
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
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
    using SafeERC20 for IERC20;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 principal, uint256 yield);
    event YieldClaimed(address indexed user, uint256 yield, uint256 epoch);

    struct StakingDetails {
        uint256 firstHalfAmount;
        uint256 firstHalfTimestamp;
        uint256 secondHalfAmount;
        uint256 secondHalfTimestamp;
        uint256 epoch;
    }

    // Yield rate is the yield per second (scaled by 1e18).
    // For example, to achieve 10% yield per epoch (30 days), set yieldRate = (0.1 * 1e18) / 2,592,000 ≈ 38,580,246,913,580.
    // Stakes in the second half of the epoch earn half the yield rate.
    uint256 public yieldRate;
    uint256 public minStakingAmount;

    uint256 public epochStart;
    uint256 public constant EPOCH_DURATION = 30 days;
    uint256 public constant HALF_EPOCH_DURATION = 15 days;

    address public token;
    IAccessControlEnumerable public accessControlEnumerable;
    bytes32 public adminRole;

    mapping(address => StakingDetails) public stakers;
    mapping(address => mapping(uint256 => bool)) public claimedEpoch;

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

    function currentEpoch() public view returns (uint256) {
        return (block.timestamp - epochStart) / EPOCH_DURATION;
    }

    function calculateYield(address staker)
        public
        view
        returns (uint256 claimableYield, uint256 ongoingYield)
    {
        StakingDetails memory details = stakers[staker];
        uint256 currentEpochIndex = currentEpoch();
        uint256 totalStaked = details.firstHalfAmount + details.secondHalfAmount;

        if (totalStaked < minStakingAmount) {
            return (0, 0);
        }

        uint256 epochStartTimestamp =
            epochStart + (details.epoch * EPOCH_DURATION);
        uint256 epochEndTimestamp = epochStartTimestamp + EPOCH_DURATION;
        uint256 effectiveTime = block.timestamp < epochEndTimestamp
            ? block.timestamp
            : epochEndTimestamp;

        uint256 yieldFirst = 0;
        uint256 yieldSecond = 0;

        if (
            details.firstHalfAmount > 0
                && effectiveTime > details.firstHalfTimestamp
        ) {
            yieldFirst = (
                details.firstHalfAmount * yieldRate
                    * (effectiveTime - details.firstHalfTimestamp)
            ) / 1e18;
        }

        if (
            details.secondHalfAmount > 0
                && effectiveTime > details.secondHalfTimestamp
        ) {
            yieldSecond = (
                details.secondHalfAmount * yieldRate
                    * (effectiveTime - details.secondHalfTimestamp)
            ) / (2 * 1e18);
        }

        uint256 totalYield = yieldFirst + yieldSecond;

        if (details.epoch == currentEpochIndex) {
            ongoingYield = totalYield;
        }

        if (
            currentEpochIndex > details.epoch && currentEpochIndex > 0
                && details.epoch == currentEpochIndex - 1
                && !claimedEpoch[staker][details.epoch]
        ) {
            claimableYield = totalYield;
        }

        return (claimableYield, ongoingYield);
    }

    function withdraw() external nonReentrant {
        StakingDetails storage details = stakers[msg.sender];
        uint256 totalStaked = details.firstHalfAmount + details.secondHalfAmount;
        require(
            totalStaked >= minStakingAmount,
            "ThriveProtocol: stake below minimum"
        );
        require(totalStaked > 0, "ThriveProtocol: no staked tokens");

        uint256 claimableYield = 0;
        if (currentEpoch() > details.epoch) {
            (claimableYield,) = calculateYield(msg.sender);
        }

        details.firstHalfAmount = 0;
        details.secondHalfAmount = 0;
        details.epoch = 0;

        if (token == address(0)) {
            _transferAmountStaked(msg.sender, totalStaked + claimableYield);
        } else {
            _transferNative(msg.sender, claimableYield);
            _transferAmountStaked(msg.sender, totalStaked);
        }

        emit Withdrawn(msg.sender, totalStaked, claimableYield);
    }

    function claimYield() external nonReentrant {
        StakingDetails storage details = stakers[msg.sender];
        uint256 totalStaked = details.firstHalfAmount + details.secondHalfAmount;

        require(
            !claimedEpoch[msg.sender][details.epoch],
            "ThriveProtocol: yield already claimed"
        );
        require(totalStaked > 0, "ThriveProtocol: no staked tokens");
        require(
            totalStaked >= minStakingAmount,
            "ThriveProtocol: stake below minimum"
        );
        require(
            currentEpoch() > details.epoch, "ThriveProtocol: epoch not finished"
        );

        (uint256 claimableYield,) = calculateYield(msg.sender);
        require(claimableYield > 0, "ThriveProtocol: no yield to claim");

        claimedEpoch[msg.sender][details.epoch] = true;

        _transferNative(msg.sender, claimableYield);
        emit YieldClaimed(msg.sender, claimableYield, details.epoch);

        details.epoch = currentEpoch();
        details.firstHalfAmount = totalStaked;
        details.secondHalfAmount = 0;
    }

    function stake(uint256 amount) external payable nonReentrant {
        _stake(amount);
    }

    function _stake(uint256 amount) internal virtual {
        uint256 epochIndex = currentEpoch();
        StakingDetails storage details = stakers[msg.sender];
        uint256 currentTotal =
            details.firstHalfAmount + details.secondHalfAmount;
        require(
            currentTotal == 0 || details.epoch == epochIndex,
            "ThriveProtocol: finalize previous epoch first"
        );

        uint256 epochPhaseStart = epochStart + (epochIndex * EPOCH_DURATION);
        if (block.timestamp < epochPhaseStart + HALF_EPOCH_DURATION) {
            if (details.firstHalfAmount == 0) {
                details.firstHalfTimestamp = block.timestamp;
            } else {
                details.firstHalfTimestamp = (
                    details.firstHalfAmount * details.firstHalfTimestamp
                        + amount * block.timestamp
                ) / (details.firstHalfAmount + amount);
            }
            details.firstHalfAmount += amount;
        } else {
            if (details.secondHalfAmount == 0) {
                details.secondHalfTimestamp = block.timestamp;
            } else {
                details.secondHalfTimestamp = (
                    details.secondHalfAmount * details.secondHalfTimestamp
                        + amount * block.timestamp
                ) / (details.secondHalfAmount + amount);
            }
            details.secondHalfAmount += amount;
        }
        details.epoch = epochIndex;

        emit Staked(msg.sender, amount);
    }

    function getStakedAmount(address user) external view returns (uint256) {
        StakingDetails memory details = stakers[user];
        return details.firstHalfAmount + details.secondHalfAmount;
    }

    function getEpochEndTimestamp(address user)
        external
        view
        returns (uint256)
    {
        StakingDetails memory details = stakers[user];
        require(
            details.firstHalfAmount + details.secondHalfAmount > 0,
            "ThriveProtocol: no staked tokens"
        );
        uint256 epochIndex = details.epoch;
        return epochStart + ((epochIndex + 1) * EPOCH_DURATION);
    }

    function _transferNative(address user, uint256 amount) internal {
        if (amount > 0) {
            (bool success,) = user.call{value: amount}("");
            require(success, "Native yield transfer failed");
        }
    }

    /**
     * @dev Transfers the staked amount to the user when token is not native.
     * This function is abstract and must be implemented by derived erc20 contracts.
     */
    function _transferAmountStaked(address user, uint256 amount)
        internal
        virtual;
}
