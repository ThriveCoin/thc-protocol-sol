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
import {AccessControlHelper} from "src/libraries/AccessControlHelper.sol";

abstract contract ThriveStakingBase is
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuard
{
    using AccessControlHelper for IAccessControlEnumerable;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);

    struct StakingDetails {
        uint256 amount;
        uint256 stakingTime;
        uint256 lastRewardTime;
    }

    uint256 public rewardRate;
    uint256 public minStakingAmount;
    uint256 public constant MIN_STAKING_PERIOD = 30 days;

    address public token;
    IAccessControlEnumerable public accessControlEnumerable;
    bytes32 public adminRole;

    mapping(address => StakingDetails) public stakers;

    function _initialize(
        address _token,
        uint256 _rewardRate,
        uint256 _minStakingAmount,
        address _accessControlEnumerable,
        bytes32 _role
    ) internal virtual {
        __Ownable_init();
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

    function calculateReward(address staker) public view returns (uint256) {
        StakingDetails storage details = stakers[staker];
        uint256 stakedDuration = block.timestamp - details.lastRewardTime;
        return (details.amount * rewardRate * stakedDuration) / 1e18;
    }
}
