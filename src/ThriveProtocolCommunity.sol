//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControlHelper} from "src/libraries/AccessControlHelper.sol";

contract ThriveProtocolCommunity is Ownable {
    using SafeERC20 for IERC20;
    using AccessControlHelper for AccessControlEnumerable;

    AccessControlEnumerable public accessControlEnumerable;

    string public name;

    address public rewardsAdmin;
    address public treasuryAdmin;
    address public validationsAdmin;
    address public foundationAdmin;

    uint256 public rewardsPercentage;
    uint256 public treasuryPercentage;
    uint256 public validationsPercentage;
    uint256 public foundationPercentage;

    mapping(address admin => mapping(address token => uint256 amount)) public
        balances;

    /**
     * @dev Emitted when a user transfer tokens from the contract
     */
    event Transfer(
        address indexed _from,
        address indexed _to,
        address indexed _token,
        uint256 _amount
    );

    /**
     * @param _owner The address of contract owner
     * @param _name The name of the community
     * @param _admins The array with addresses of admins
     * @param _percentages The array with value of percents for distribution
     * @param _accessControlEnumerable The address of access control enumerable contract
     */
    constructor(
        address _owner,
        string memory _name,
        address[4] memory _admins,
        uint256[4] memory _percentages,
        address _accessControlEnumerable
    ) Ownable(_owner) {
        name = _name;

        accessControlEnumerable =
            AccessControlEnumerable(_accessControlEnumerable);

        _setAdmins(_admins[0], _admins[1], _admins[2], _admins[3]);

        _setPercentage(
            _percentages[0], _percentages[1], _percentages[2], _percentages[3]
        );
    }

    /**
     * @dev Modifier to only allow execution by admins.
     * If the caller is not an admin, reverts with a corresponding message
     */
    modifier onlyAdmin() {
        accessControlEnumerable.checkAdminRole(msg.sender);
        _;
    }

    /**
     * @notice Transfers _amount of the _token to the smart contract
     * and increases the balances of administrators of treasury,
     * validations, rewards and foundations in the following percentages for the _token
     * @param _token The address of ERC20 contract
     * @param _amount The amount of token to deposit
     */
    function deposit(address _token, uint256 _amount) public {
        balances[treasuryAdmin][_token] += (_amount * treasuryPercentage) / 100;
        balances[validationsAdmin][_token] +=
            (_amount * validationsPercentage) / 100;
        balances[foundationAdmin][_token] +=
            (_amount * foundationPercentage) / 100;
        balances[rewardsAdmin][_token] += (_amount * rewardsPercentage) / 100;

        uint256 dust = _amount
            - (
                balances[rewardsAdmin][_token] + balances[treasuryAdmin][_token]
                    + balances[validationsAdmin][_token]
                    + balances[foundationAdmin][_token]
            );
        balances[rewardsAdmin][_token] += dust;

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @notice Transfers _amount of the _token to the smart contract
     * and increases the balance of the validators administrator account by _amount for the respective _token
     * @param _token The address of ERC20 contract
     * @param _amount The amount of token to deposit
     */
    function validationsDeposit(address _token, uint256 _amount) public {
        balances[validationsAdmin][_token] += _amount;
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @notice Transfers _amount of the _token to the message caller's account
     * @param _token The address of ERC20 contract
     * @param _amount The amount of token to withdraw
     */
    function withdraw(address _token, uint256 _amount) public {
        require(balances[msg.sender][_token] >= _amount, "Insufficient balance");
        balances[msg.sender][_token] -= _amount;
        IERC20(_token).safeTransfer(msg.sender, _amount);
        emit Transfer(address(this), msg.sender, _token, _amount);
    }

    /**
     * @notice Transfers _amount of the _token to address _to
     * @param _token The address of ERC20 contract
     * @param _amount The amount of token to withdraw
     */
    function transfer(address _to, address _token, uint256 _amount) public {
        _transfer(msg.sender, _to, _token, _amount);
    }

    /**
     * @notice Sets the rewards admin address
     * can call only DEFAULT_ADMIN account
     * @param _rewardsAdmin The address of the account who has administrator rights for the funds allocated for rewards
     */
    function setRewardsAdmin(address _rewardsAdmin) external onlyAdmin {
        rewardsAdmin = _rewardsAdmin;
    }

    /**
     * @notice Sets the treasury admin address
     * can call only DEFAULT_ADMIN account
     * @param _treasuryAdmin The address of the account who has administrator rights for the funds allocated for DAO treasury
     */
    function setTreasuryAdmin(address _treasuryAdmin) external onlyAdmin {
        treasuryAdmin = _treasuryAdmin;
    }

    /**
     * @notice Sets the validations admin address
     * can call only DEFAULT_ADMIN account
     * @param _validationsAdmin The address of the account who has administrator rights for the funds allocated for validations
     */
    function setValidationsAdmin(address _validationsAdmin)
        external
        onlyAdmin
    {
        validationsAdmin = _validationsAdmin;
    }

    /**
     * @notice Sets the foundation admin address
     * can call only DEFAULT_ADMIN account
     * @param _foundationAdmin The address of the account who has administrator rights for the funds allocated for the foundation
     */
    function setFoundationAdmin(address _foundationAdmin) external onlyAdmin {
        foundationAdmin = _foundationAdmin;
    }

    /**
     * @notice Sets the percentages for distribution
     * can call only DEFAULT_ADMIN account
     * @param _rewardsPercentage The percentage for the rewards admin
     * @param _treasuryPercentage The percentage for the treasury admin
     * @param _validationsPercentage The percentage for the validations admin
     * @param _foundationPercentage The percentage for the foundation admin
     */
    function setPercentage(
        uint256 _rewardsPercentage,
        uint256 _treasuryPercentage,
        uint256 _validationsPercentage,
        uint256 _foundationPercentage
    ) external onlyAdmin {
        require(
            _rewardsPercentage + _treasuryPercentage + _validationsPercentage
                + _foundationPercentage == 100,
            "Percentages must add up to 100"
        );

        rewardsPercentage = _rewardsPercentage;
        treasuryPercentage = _treasuryPercentage;
        validationsPercentage = _validationsPercentage;
        foundationPercentage = _foundationPercentage;
    }

    /**
     * @dev Sets the AccessControlEnumerable contract address.
     * Only the owner of this contract can call this function.
     *
     * @param _accessControlEnumerable The address of the new AccessControlEnumerable contract.
     */
    function setAccessControlEnumerable(address _accessControlEnumerable)
        external
        onlyOwner
    {
        accessControlEnumerable =
            AccessControlEnumerable(_accessControlEnumerable);
    }

    /**
     * @notice Sets the admins' addresses
     * @param _rewardsAdmin The address of the account who has administrator rights for the funds allocated for rewards
     * @param _treasuryAdmin The address of the account who has administrator rights for the funds allocated for DAO treasury
     * @param _validationsAdmin The address of the account who has administrator rights for the funds allocated for validations
     * @param _foundationAdmin The address of the account who has administrator rights for the funds allocated for the foundation
     */
    function _setAdmins(
        address _rewardsAdmin,
        address _treasuryAdmin,
        address _validationsAdmin,
        address _foundationAdmin
    ) internal {
        rewardsAdmin = _rewardsAdmin;
        treasuryAdmin = _treasuryAdmin;
        validationsAdmin = _validationsAdmin;
        foundationAdmin = _foundationAdmin;
    }

    /**
     * @notice Sets the percentages for distribution
     * @param _rewardsPercentage The percentage for the rewards admin
     * @param _treasuryPercentage The percentage for the treasury admin
     * @param _validationsPercentage The percentage for the validations admin
     * @param _foundationPercentage The percentage for the foundation admin
     */
    function _setPercentage(
        uint256 _rewardsPercentage,
        uint256 _treasuryPercentage,
        uint256 _validationsPercentage,
        uint256 _foundationPercentage
    ) internal {
        rewardsPercentage = _rewardsPercentage;
        treasuryPercentage = _treasuryPercentage;
        validationsPercentage = _validationsPercentage;
        foundationPercentage = _foundationPercentage;
    }

    /**
     * @notice Internal function to handle the token transfer logic
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _token The address of ERC20 contract
     * @param _amount The amount of token to transfer
     */
    function _transfer(
        address _from,
        address _to,
        address _token,
        uint256 _amount
    ) internal {
        require(balances[_from][_token] >= _amount, "Insufficient balance");
        balances[_from][_token] -= _amount;
        IERC20(_token).safeTransfer(_to, _amount);
        emit Transfer(address(this), _to, _token, _amount);
    }
}
