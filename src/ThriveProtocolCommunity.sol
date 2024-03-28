//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract ThriveProtocolCommunity is AccessControl {
    using SafeERC20 for IERC20;

    string private name;

    address private rewardsAdmin;
    address private treasuryAdmin;
    address private validationsAdmin;
    address private foundationAdmin;

    mapping(address admin => mapping(address token => uint256 amount))
        public balances;

    event Transfer(
        address indexed _from,
        address indexed _to,
        address indexed _token,
        uint256 _amount
    );

    constructor(
        string memory _name,
        address _rewardsAdmin,
        address _treasuryAdmin,
        address _validationsAdmin,
        address _foundationAdmin
    ) {
        name = _name;
        rewardsAdmin = _rewardsAdmin;
        treasuryAdmin = _treasuryAdmin;
        validationsAdmin = _validationsAdmin;
        foundationAdmin = _foundationAdmin;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function deposit(address _token, uint256 _amount) public {
        balances[rewardsAdmin][_token] += (_amount / 100) * 80;
        balances[treasuryAdmin][_token] += (_amount / 100) * 5;
        balances[validationsAdmin][_token] += (_amount / 100) * 5;
        balances[foundationAdmin][_token] += (_amount / 100) * 10;

        uint256 dust = _amount -
            (balances[rewardsAdmin][_token] +
                balances[treasuryAdmin][_token] +
                balances[validationsAdmin][_token] +
                balances[foundationAdmin][_token]);
        balances[rewardsAdmin][_token] += dust;

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function validationsDeposit(address _token, uint256 _amount) public {
        balances[validationsAdmin][_token] += _amount;
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(address _token, uint256 _amount) public {
        require(
            balances[msg.sender][_token] >= _amount,
            "Insufficient balance"
        );
        balances[msg.sender][_token] -= _amount;
        IERC20(_token).safeTransfer(msg.sender, _amount);
        emit Transfer(address(this), msg.sender, _token, _amount);
    }

    function transfer(address _to, address _token, uint256 _amount) public {
        require(
            balances[msg.sender][_token] >= _amount,
            "Insufficient balance"
        );
        balances[msg.sender][_token] -= _amount;
        IERC20(_token).safeTransfer(_to, _amount);
        emit Transfer(address(this), _to, _token, _amount);
    }

    function setRewardsAdmin(
        address newRewardsAdmin
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        rewardsAdmin = newRewardsAdmin;
    }

    function setTreasuryAdmin(
        address newTreasuryAdmin
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        treasuryAdmin = newTreasuryAdmin;
    }

    function setValidationsAdmin(
        address newValidationsAdmin
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        validationsAdmin = newValidationsAdmin;
    }

    function setFoundationAdmin(
        address newFoundationAdmin
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        foundationAdmin = newFoundationAdmin;
    }

    function getName() public view returns (string memory) {
        return name;
    }

    function getRewardsAdmin() public view returns (address) {
        return rewardsAdmin;
    }

    function getTreasuryAdmin() public view returns (address) {
        return treasuryAdmin;
    }

    function getValidationsAdmin() public view returns (address) {
        return validationsAdmin;
    }

    function getFoundationAdmin() public view returns (address) {
        return foundationAdmin;
    }
}
