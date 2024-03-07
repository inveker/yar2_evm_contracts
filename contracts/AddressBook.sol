// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { ERC1967ProxyCreate2 } from "./utils/ERC1967ProxyCreate2.sol";
import { IssuedERC20 } from "./tokens/IssuedERC20.sol";

contract AddressBook is UUPSUpgradeable {
    struct Admins {
        address owner;
        address transferValidator;
    }
    Admins public admins;

    address public treasury;

    function initialize(
        Admins calldata _admins
    ) public initializer {
        admins = _admins;
    }

    function requireOnlyOwner(address _account) public view {
        require(_account == admins.owner, "only owner!");
    }

    function requireTransferValidator(address _account) public view {
        require(_account == admins.transferValidator, "only transfer validator!");
    }

    function setTreasury(address _contract) public {
        treasury = _contract;
    }

    function _authorizeUpgrade(address) internal view override {
        requireOnlyOwner(msg.sender);
    }

    constructor() {
        _disableInitializers();
    }
}
