// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MultisigWallet {
    uint256 public requiredSigners;
    mapping(address => bool) public signers;
    uint256 public signersCount;

    /// @notice Signatures have already been registered
    mapping(bytes32 messageHash => mapping(address signer => bool)) public alreadyVerified;

    constructor(uint256 _requiredSigners, address[] memory _signers) {
        require(_requiredSigners > 0, "_requiredSigners must be greater than zero!");
        require(_signers.length >= _requiredSigners, "_requiredSigners > _signers.length");
        requiredSigners = _requiredSigners;
        for (uint256 i; i < _signers.length; ++i) {
            require(_signers[i] != address(0), "_signers contains zero address!");
            require(signers[_signers[i]] == false, "signer exists!");
            signers[_signers[i]] = true;
        }
        signersCount = _signers.length;
    }

    function submitTransaction(
        address[] calldata _signers,
        bytes[] calldata _signatures,
        address _target,
        uint256 _value,
        bytes calldata _data
    ) external payable {
        bytes32 _messageHash = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    block.chainid,
                    address(this),
                    MultisigWallet.submitTransaction.selector,
                    _target,
                    _value,
                    _data
                )
            )
        );
        uint256 verifiedSignsCount;
        for (uint256 i; i < _signers.length; ++i) {
            require(alreadyVerified[_messageHash][_signers[i]] == false, "signature already used!");
            require(
                SignatureChecker.isValidSignatureNow(_signers[i], _messageHash, _signatures[i]),
                "signature!"
            );
            alreadyVerified[_messageHash][_signers[i]] = true;
            ++verifiedSignsCount;
        }
        require(verifiedSignsCount >= requiredSigners, "requiredSigners!");

        (bool success, ) = _target.call{ value: _value }(_data);
        require(success, "transaction call failure!");
    }
}
