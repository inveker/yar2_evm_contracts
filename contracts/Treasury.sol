// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { ERC1967ProxyCreate2 } from "./utils/ERC1967ProxyCreate2.sol";
import { IssuedERC20 } from "./tokens/IssuedERC20.sol";
import { IAddressBook } from "./interfaces/IAddressBook.sol";

contract Treasury is UUPSUpgradeable {
    using SafeERC20 for IERC20;
    IAddressBook public addressBook;

    function initialize(address _addressBook) public initializer {
        addressBook = IAddressBook(_addressBook);
    }

    function withdraw(address _token, uint256 _amount, address _recipient) external {
        addressBook.requireOnlyOwner(msg.sender);
        if (_token == address(0)) {
            (bool success, ) = _recipient.call{ value: _amount }("");
            require(success, "transfer failed!");
        } else {
            IERC20(_token).safeTransfer(_recipient, _amount);
        }
    }

    function _authorizeUpgrade(address) internal view override {
        addressBook.requireOnlyOwner(msg.sender);
    }

    constructor() {
        _disableInitializers();
    }
}
