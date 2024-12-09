// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    ERC20,
    ERC20Burnable
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IThriveIERC20Wrapper} from "src/IThriveIERC20Wrapper.sol";

contract ThriveIERC20Wrapper is IThriveIERC20Wrapper, ERC20Burnable, Ownable {
    address public minter;

    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
        Ownable(msg.sender)
    {}

    /**
     * @dev Modifier to only allow execution by minter.
     * If the caller is not minter, reverts with a corresponding message
     */
    modifier onlyMinter() {
        require(_msgSender() == minter, "ThriveProtocol: must be minter");
        _;
    }

    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
    }

    function mint(address recipient, uint256 amount) external onlyMinter {
        _mint(recipient, amount);
    }

    function burn(uint256 value)
        public
        virtual
        override(ERC20Burnable, IThriveIERC20Wrapper)
    {
        ERC20Burnable.burn(value);
    }

    function burnFrom(address account, uint256 value)
        public
        virtual
        override(ERC20Burnable, IThriveIERC20Wrapper)
    {
        ERC20Burnable.burnFrom(account, value);
    }
}
