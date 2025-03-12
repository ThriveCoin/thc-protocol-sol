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
    event YieldStaked(address indexed user, uint256 amount, uint256 epoch);

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
    uint256 public EPOCH_DURATION;
    uint256 public HALF_EPOCH_DURATION;

    address public token;
    IAccessControlEnumerable public accessControlEnumerable;
    bytes32 public adminRole;

    mapping(address => StakingDetails) public stakers;
    mapping(address => mapping(uint256 => bool)) public claimedEpoch;
    mapping(address => uint256) public claimableYield;

    function _initialize(
        address _token,
        uint256 _yieldRate,
        uint256 _minStakingAmount,
        uint256 _epochDuration,
        uint256 _halfEpochDuration,
        address _accessControlEnumerable,
        bytes32 _role
    ) internal virtual {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        yieldRate = _yieldRate;
        minStakingAmount = _minStakingAmount;
        token = _token;
        EPOCH_DURATION = _epochDuration;
        HALF_EPOCH_DURATION = _halfEpochDuration;
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
        returns (uint256 totalClaimableYield, uint256 ongoingYield)
    {
        StakingDetails memory details = stakers[staker];
        uint256 currentEpochIndex = currentEpoch();
        uint256 totalStaked = details.firstHalfAmount + details.secondHalfAmount;

        if (totalStaked < minStakingAmount) {
            return (0, 0);
        }

        totalClaimableYield = claimableYield[staker];
        uint256 epochsElapsed = currentEpochIndex > details.epoch
            ? currentEpochIndex - details.epoch
            : 0;

        if (epochsElapsed > 0) {
            uint256 yieldPerEpochFirst =
                details.firstHalfAmount * yieldRate * EPOCH_DURATION / 1e18;
            uint256 yieldPerEpochSecond = details.secondHalfAmount * yieldRate
                * EPOCH_DURATION / (2 * 1e18);
            uint256 totalYieldPerEpoch =
                yieldPerEpochFirst + yieldPerEpochSecond;

            totalClaimableYield += totalYieldPerEpoch * epochsElapsed;

            uint256 firstEpochStart = details.firstHalfTimestamp;
            uint256 firstEpochEnd =
                epochStart + ((details.epoch + 1) * EPOCH_DURATION);
            uint256 firstEpochYieldFirst = details.firstHalfAmount * yieldRate
                * (firstEpochEnd - firstEpochStart) / 1e18;
            uint256 firstEpochYieldSecond = details.secondHalfAmount * yieldRate
                * (firstEpochEnd - details.secondHalfTimestamp) / (2 * 1e18);

            totalClaimableYield -= (
                totalYieldPerEpoch
                    - (firstEpochYieldFirst + firstEpochYieldSecond)
            );
        }

        if (totalStaked > 0) {
            uint256 currentEpochStart =
                epochStart + (currentEpochIndex * EPOCH_DURATION);
            uint256 effectiveTime = block.timestamp - currentEpochStart;

            if (epochsElapsed == 0) {
                effectiveTime = block.timestamp - details.firstHalfTimestamp;
                ongoingYield +=
                    details.firstHalfAmount * yieldRate * effectiveTime / 1e18;
                ongoingYield += details.secondHalfAmount * yieldRate
                    * effectiveTime / (2 * 1e18);
            } else {
                ongoingYield += totalStaked * yieldRate * effectiveTime / 1e18;
            }
        }

        return (totalClaimableYield, ongoingYield);
    }

    function _updateStakeAndYield(address user) internal {
        StakingDetails storage details = stakers[user];
        uint256 currentEpochIndex = currentEpoch();
        uint256 totalStaked = details.firstHalfAmount + details.secondHalfAmount;

        if (
            totalStaked < minStakingAmount || details.epoch >= currentEpochIndex
        ) {
            return;
        }

        (uint256 newClaimableYield,) = calculateYield(user);
        claimableYield[user] = newClaimableYield;

        details.firstHalfAmount = totalStaked;
        details.secondHalfAmount = 0;
        details.firstHalfTimestamp =
            epochStart + (currentEpochIndex * EPOCH_DURATION);
        details.epoch = currentEpochIndex;
    }

    function withdraw() external nonReentrant {
        _updateStakeAndYield(msg.sender);

        StakingDetails storage details = stakers[msg.sender];
        uint256 totalStaked = details.firstHalfAmount + details.secondHalfAmount;
        require(
            totalStaked >= minStakingAmount,
            "ThriveProtocol: stake below minimum"
        );
        require(totalStaked > 0, "ThriveProtocol: no staked tokens");

        uint256 amountToWithdraw = claimableYield[msg.sender];

        if (amountToWithdraw > 0) {
            claimableYield[msg.sender] = 0;
        }

        details.firstHalfAmount = 0;
        details.secondHalfAmount = 0;
        details.epoch = 0;

        if (token == address(0)) {
            _transferAmountStaked(msg.sender, totalStaked + amountToWithdraw);
        } else {
            if (amountToWithdraw > 0) {
                _transferNative(msg.sender, amountToWithdraw);
            }
            _transferAmountStaked(msg.sender, totalStaked);
        }

        emit Withdrawn(msg.sender, totalStaked, amountToWithdraw);
    }

    function claimYield() external nonReentrant {
        _updateStakeAndYield(msg.sender);

        StakingDetails storage details = stakers[msg.sender];
        uint256 totalStaked = details.firstHalfAmount + details.secondHalfAmount;
        require(totalStaked > 0, "ThriveProtocol: no staked tokens");
        require(
            totalStaked >= minStakingAmount,
            "ThriveProtocol: stake below minimum"
        );

        uint256 amountToClaim = claimableYield[msg.sender];
        require(amountToClaim > 0, "ThriveProtocol: no yield to claim");

        claimableYield[msg.sender] = 0;
        _transferNative(msg.sender, amountToClaim);
        emit YieldClaimed(msg.sender, amountToClaim, currentEpoch() - 1);
    }

    function stakeYield() external nonReentrant {
        _updateStakeAndYield(msg.sender);

        StakingDetails storage details = stakers[msg.sender];
        uint256 totalStaked = details.firstHalfAmount + details.secondHalfAmount;
        require(totalStaked > 0, "ThriveProtocol: no staked tokens");
        require(
            totalStaked >= minStakingAmount,
            "ThriveProtocol: stake below minimum"
        );

        uint256 amountToStake = claimableYield[msg.sender];
        require(amountToStake > 0, "ThriveProtocol: no yield to stake");

        claimableYield[msg.sender] = 0;

        uint256 epochPhaseStart = epochStart + (details.epoch * EPOCH_DURATION);
        if (block.timestamp < epochPhaseStart + HALF_EPOCH_DURATION) {
            details.firstHalfTimestamp = (
                details.firstHalfAmount * details.firstHalfTimestamp
                    + amountToStake * block.timestamp
            ) / (details.firstHalfAmount + amountToStake);
            details.firstHalfAmount += amountToStake;
        } else {
            if (details.secondHalfAmount == 0) {
                details.secondHalfTimestamp = block.timestamp;
            } else {
                details.secondHalfTimestamp = (
                    details.secondHalfAmount * details.secondHalfTimestamp
                        + amountToStake * block.timestamp
                ) / (details.secondHalfAmount + amountToStake);
            }
            details.secondHalfAmount += amountToStake;
        }

        emit YieldStaked(msg.sender, amountToStake, details.epoch);
    }

    function stake(uint256 amount) external payable nonReentrant {
        _stake(amount);
    }

    function _stake(uint256 amount) internal virtual {
        _updateStakeAndYield(msg.sender);

        StakingDetails storage details = stakers[msg.sender];
        uint256 epochIndex = currentEpoch();
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
