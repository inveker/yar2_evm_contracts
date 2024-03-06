// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { ERC1967ProxyCreate2 } from "./utils/ERC1967ProxyCreate2.sol";
import { IssuedERC20 } from "./tokens/IssuedERC20.sol";

contract BridgesConfig is UUPSUpgradeable {
    struct Bridge {
        uint256 tranferGasAmount;
        uint256 deployGasAmount;
    }
    mapping(string typeName => Bridge) public bridges;

    struct Chain {
        uint256 chainId;
        string defaultRpcUrl;
    }
    Chain[] public chains;

    struct Admins {
        address owner;
    }
    Admins public admins;

    struct Fees {
        uint256 gasFeesMultiplier;
        uint256 bridgeFeesUSD;
    }
    Fees public fees;

    struct Meta {
        string agregationServiceUrl;
        string deployServiceUrl;
    }
    Meta public meta;

    function initialize(
        Chain[] calldata _chains,
        Admins calldata _admins,
        Fees calldata _fees,
        Meta calldata _meta
    ) public initializer {
        for (uint256 i; i < _chains.length; ++i) {
            chains.push(_chains[i]);
        }
        admins = _admins;
        fees = _fees;
        meta = _meta;
    }

    function requireOnlyOwner(address _account) public view {
        require(_account == admins.owner, "only owner!");
    }

    function setFees(Fees calldata _fees) external {
        requireOnlyOwner(msg.sender);
        fees = _fees;
    }

    function setAdmins(Admins calldata _admins) external {
        requireOnlyOwner(msg.sender);
        admins = _admins;
    }

    function addChain(Chain calldata _chain) external {
        requireOnlyOwner(msg.sender);
        chains.push(_chain);
    }

    function setMeta(Meta calldata _meta) external {
        requireOnlyOwner(msg.sender);
        meta = _meta;
    }

    function setBridge(string calldata _typeName, Bridge calldata _bridge) external {
        requireOnlyOwner(msg.sender);
        bridges[_typeName] = _bridge;
    }

    function _authorizeUpgrade(address) internal view override {
        requireOnlyOwner(msg.sender);
    }

    constructor() {
        _disableInitializers();
    }
}
