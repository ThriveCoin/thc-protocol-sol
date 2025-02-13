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
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);
    event RewardClaimed(address indexed user, uint256 reward);
    event ContributionDataRequested(address indexed user, uint256 requestId);
    event ContributionDataFulfilled(address indexed user, uint256 reward);

    struct StakingDetails {
        uint256 amount;
        uint256 stakingTime;
        uint256 lastRewardTime;
    }

    uint256 public rewardRate;
    uint256 public minStakingAmount;
    uint256 public constant MIN_STAKING_PERIOD = 30 days;

    // For ERC20 staking, token != address(0); for native staking, token == address(0)
    address public token;
    IAccessControlEnumerable public accessControlEnumerable;
    bytes32 public adminRole;

    mapping(address => StakingDetails) public stakers;
    mapping(uint256 => address) public requestIdToUser;
    mapping(address => bool) public pendingContributionRequests;
    mapping(address => uint256) public userContributionRewards;
    mapping(address => uint256) public userContributionPercentage;
    uint256 public requestCounter;

    function _initialize(
        address _token,
        uint256 _rewardRate,
        uint256 _minStakingAmount,
        address _accessControlEnumerable,
        bytes32 _role
    ) internal virtual {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        rewardRate = _rewardRate;
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

    function setRewardRate(uint256 _rewardRate) external onlyAdmin {
        rewardRate = _rewardRate;
    }

    function setMinStakingAmount(uint256 _minStakingAmount)
        external
        onlyAdmin
    {
        minStakingAmount = _minStakingAmount;
    }

    /// @notice Calculates staking reward based on the amount staked and duration since the last reward claim.
    function calculateReward(address staker) public view returns (uint256) {
        StakingDetails memory details = stakers[staker];
        uint256 stakedDuration = block.timestamp - details.lastRewardTime;

        uint256 decimals =
            token == address(0) ? 18 : IERC20Metadata(token).decimals();
        return (details.amount * rewardRate * stakedDuration) / (10 ** decimals);
    }

    // store the contribution reward
    function fulfillContributionData(
        uint256 requestId,
        uint256 totalEpochYield,
        uint256 contributionPercentage
    ) external onlyAdmin {
        address user = requestIdToUser[requestId];
        require(user != address(0), "Invalid requestId");

        userContributionPercentage[user] = contributionPercentage;
        uint256 contributionReward =
            (totalEpochYield * contributionPercentage) / 100;

        userContributionRewards[user] = contributionReward;
        pendingContributionRequests[user] = false; // Reset pending request flag

        emit ContributionDataFulfilled(user, contributionReward);
    }

    // fetches the stored reward
    function getContributionReward(address user)
        internal
        view
        returns (uint256)
    {
        return userContributionRewards[user];
    }

    /// @notice Claims the yield (staking rewards plus contribution rewards) without unstaking.
    function claimYield() external nonReentrant {
        StakingDetails storage details = stakers[msg.sender];
        require(details.amount > 0, "ThriveProtocol: no staked tokens");

        uint256 contributionReward = getContributionReward(msg.sender);

        if (contributionReward == 0 && !pendingContributionRequests[msg.sender])
        {
            requestCounter++;
            requestIdToUser[requestCounter] = msg.sender;
            pendingContributionRequests[msg.sender] = true;

            emit ContributionDataRequested(msg.sender, requestCounter);
            return;
        }

        require(
            contributionReward > 0, "ThriveProtocol: pending contribution data"
        );

        uint256 reward = calculateReward(msg.sender) + contributionReward;
        require(reward > 0, "ThriveProtocol: no rewards to claim");

        details.lastRewardTime = block.timestamp;
        userContributionRewards[msg.sender] = 0;
        pendingContributionRequests[msg.sender] = false; // Reset the pending status

        _transferReward(msg.sender, reward);
        emit RewardClaimed(msg.sender, reward);
    }

    /// @notice Unstakes the full staked amount, transfers it along with pending rewards, and resets the staking details.
    function withdraw() external nonReentrant {
        StakingDetails storage details = stakers[msg.sender];
        require(details.amount > 0, "ThriveProtocol: no staked tokens");
        require(
            block.timestamp >= details.stakingTime + MIN_STAKING_PERIOD,
            "ThriveProtocol: 30-day lockup"
        );

        uint256 reward = calculateReward(msg.sender);
        uint256 totalAmount = details.amount + reward;

        _transferReward(msg.sender, totalAmount);

        emit Withdrawn(msg.sender, details.amount, reward);

        details.amount = 0;
        details.stakingTime = 0;
        details.lastRewardTime = 0;
    }

    /// @notice External stake function that calls the internal _stake; can be overridden.
    function stake(uint256 amount) external nonReentrant {
        _stake(amount);
    }

    /// @dev Common internal function to update staking details and emit the Staked event.
    function _stake(uint256 amount) internal virtual {
        uint256 pendingYield = calculateReward(msg.sender);
        require(
            pendingYield == 0,
            "ThriveProtocol: claim yield first and retry stake again"
        );

        StakingDetails storage details = stakers[msg.sender];
        details.amount += amount;
        details.stakingTime = block.timestamp;
        details.lastRewardTime = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    /// @dev Token-specific reward transfer function to be implemented in derived contracts.
    function _transferReward(address user, uint256 amount) internal virtual;
}
