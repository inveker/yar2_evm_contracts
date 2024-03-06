// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IAddressBook {
    function requireOnlyOwner(address _account) external view;
    function requireTransferValidator(address _account) external view;
}
