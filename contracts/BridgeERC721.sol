// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { ERC1967ProxyCreate2 } from "./utils/ERC1967ProxyCreate2.sol";
import { IssuedERC721 } from "./tokens/IssuedERC721.sol";
import { IAddressBook } from "./interfaces/IAddressBook.sol";

contract BridgeERC721 is IERC721Receiver, UUPSUpgradeable {
    IAddressBook public addressBook;

    address public validator;

    uint256 public currentChain;

    uint256 public nonce;

    bool public isProxyChain;

    mapping(address => bool) public issuedTokens;

    mapping(uint256 => mapping(uint256 => bool)) public registeredNonces;

    address public issuedTokenImplementation;

    uint256 public initBlock;

    event TransferToOtherChain(
        bytes32 indexed transferId,
        uint256 nonce,
        uint256 initialChain,
        uint256 originalChain,
        bytes originalTokenAddress,
        uint256 targetChain,
        uint256 tokenId,
        bytes sender,
        bytes recipient,
        string tokenName,
        string tokenSymbol,
        string tokenUri
    );

    event TransferFromOtherChain(
        bytes32 indexed transferId,
        uint256 externalNonce,
        uint256 originalChain,
        bytes originalToken,
        uint256 initialChain,
        uint256 targetChain,
        uint256 tokenId,
        bytes sender,
        bytes recipient
    );

    function initialize(
        address _addressBook,
        bool _isProxyChain,
        address _validator
    ) public initializer {
        addressBook = IAddressBook(_addressBook);
        initBlock = block.number;
        currentChain = block.chainid;
        isProxyChain = _isProxyChain;
        issuedTokenImplementation = address(new IssuedERC721());
        validator = _validator;
    }

    function _authorizeUpgrade(address) internal view override {
        addressBook.requireOnlyOwner(msg.sender);
    }

    constructor() {
        _disableInitializers();
    }

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function enforceIsValidator(address account) internal view {
        require(account == validator, "BridgeERC721: Only validator!");
    }

    function setValidator(address _newValidator) external {
        enforceIsValidator(msg.sender);
        validator = _newValidator;
    }

    function getTransferId(uint256 _nonce, uint256 _initialChain) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_nonce, _initialChain));
    }

    function tranferToOtherChain(
        address _transferedToken,
        uint256 _tokenId,
        uint256 _targetChain,
        bytes calldata _recipient
    ) external {
        bool isIssuedToken = issuedTokens[_transferedToken];
        uint256 initialChain = currentChain;
        uint256 _nonce = nonce++;
        uint256 originalChain;
        bytes memory originalToken;
        string memory tokenName;
        string memory tokenSymbol;
        string memory tokenUri;

        if (isIssuedToken) {
            // There ISSUED token
            IssuedERC721 issuedToken = IssuedERC721(_transferedToken);
            (originalChain, originalToken, tokenName, tokenSymbol) = issuedToken
                .getOriginalTokenInfo();
            tokenUri = issuedToken.tokenURI(_tokenId);
            if (originalChain == _targetChain && isProxyChain) {
                issuedToken.permissionedTransferFrom(msg.sender, address(this), _tokenId);
            } else {
                issuedToken.burn(_tokenId);
            }
        } else {
            // There ORIGINAL token
            IERC721Metadata token = IERC721Metadata(_transferedToken);
            originalChain = initialChain;
            originalToken = abi.encode(_transferedToken);
            try token.name() returns (string memory _tokenName) {
                tokenName = _tokenName;
            } catch {
                tokenName = "";
            }
            try token.symbol() returns (string memory _tokenSymbol) {
                tokenSymbol = _tokenSymbol;
            } catch {
                tokenSymbol = "";
            }
            try token.tokenURI(_tokenId) returns (string memory _tokenUri) {
                tokenUri = _tokenUri;
            } catch {
                tokenUri = "";
            }
            token.safeTransferFrom(msg.sender, address(this), _tokenId);
        }

        emit TransferToOtherChain(
            getTransferId(_nonce, initialChain),
            _nonce,
            initialChain,
            originalChain,
            originalToken,
            _targetChain,
            _tokenId,
            abi.encode(msg.sender),
            _recipient,
            tokenName,
            tokenSymbol,
            tokenUri
        );
    }

    struct TokenInfo {
        string name;
        string symbol;
        string tokenUri;
    }

    function tranferFromOtherChain(
        uint256 _externalNonce,
        uint256 _originalChain,
        bytes calldata _originalToken,
        uint256 _initialChain,
        uint256 _targetChain,
        uint256 _tokenId,
        bytes calldata _sender,
        bytes calldata _recipient,
        TokenInfo calldata _tokenInfo
    ) external {
        addressBook.requireTransferValidator(msg.sender);

        require(
            !registeredNonces[_initialChain][_externalNonce],
            "BridgeERC721: nonce already registered"
        );

        registeredNonces[_initialChain][_externalNonce] = true;

        uint256 _currentChain = currentChain;

        require(_initialChain != _currentChain, "BridgeERC721: initialChain == currentChain");

        if (_currentChain == _targetChain) {
            // This is TARGET chain
            address recipientAddress = abi.decode(_recipient, (address));

            if (currentChain == _originalChain) {
                // This is ORIGINAL chain
                address originalTokenAddress = abi.decode(_originalToken, (address));
                IERC721Metadata(originalTokenAddress).safeTransferFrom(
                    address(this),
                    recipientAddress,
                    _tokenId
                );
            } else {
                // This is SECONDARY chain
                address issuedTokenAddress = getIssuedTokenAddress(_originalChain, _originalToken);
                if (!isIssuedTokenPublished(issuedTokenAddress))
                    publishNewToken(_originalChain, _originalToken, _tokenInfo);
                IssuedERC721(issuedTokenAddress).mint(
                    recipientAddress,
                    _tokenId,
                    _tokenInfo.tokenUri
                );
            }

            emit TransferFromOtherChain(
                getTransferId(_externalNonce, _initialChain),
                _externalNonce,
                _originalChain,
                _originalToken,
                _initialChain,
                _targetChain,
                _tokenId,
                _sender,
                _recipient
            );
        } else {
            // This is PROXY chain
            require(isProxyChain, "BridgeERC721: Only proxy bridge!");

            address issuedTokenAddress = getIssuedTokenAddress(_originalChain, _originalToken);
            if (!isIssuedTokenPublished(issuedTokenAddress))
                publishNewToken(_originalChain, _originalToken, _tokenInfo);

            if (_targetChain == _originalChain) {
                // BURN PROXY ISSUED TOKENS
                IssuedERC721(issuedTokenAddress).burn(_tokenId);
            } else if (_initialChain == _originalChain) {
                // LOCK PROXY ISSUED TOKENS
                IssuedERC721(issuedTokenAddress).mint(address(this), _tokenId, _tokenInfo.tokenUri);
            }

            bytes memory sender = _sender; // TODO: fix Error HH600
            emit TransferToOtherChain(
                getTransferId(_externalNonce, _initialChain),
                _externalNonce,
                _initialChain,
                _originalChain,
                _originalToken,
                _targetChain,
                _tokenId,
                sender,
                _recipient,
                _tokenInfo.name,
                _tokenInfo.symbol,
                _tokenInfo.tokenUri
            );
        }
    }

    function isIssuedTokenPublished(address _issuedToken) public view returns (bool) {
        return issuedTokens[_issuedToken];
    }

    function getIssuedTokenAddress(
        uint256 _originalChain,
        bytes calldata _originalToken
    ) public view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(_originalChain, _originalToken));
        return
            address(
                uint160(
                    uint(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                address(this),
                                salt,
                                keccak256(abi.encodePacked(type(ERC1967ProxyCreate2).creationCode))
                            )
                        )
                    )
                )
            );
    }

    function publishNewToken(
        uint256 _originalChain,
        bytes calldata _originalToken,
        TokenInfo calldata _tokenInfo
    ) internal returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(_originalChain, _originalToken));
        ERC1967ProxyCreate2 issuedToken = new ERC1967ProxyCreate2{ salt: salt }();
        issuedToken.init(
            issuedTokenImplementation,
            abi.encodeWithSelector(
                IssuedERC721.initialize.selector,
                _originalChain,
                _originalToken,
                _tokenInfo.name,
                _tokenInfo.symbol
            )
        );

        address issuedTokenAddress = address(issuedToken);
        issuedTokens[issuedTokenAddress] = true;
        return issuedTokenAddress;
    }

    function getTranferId(uint256 _nonce, uint256 _initialChain) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(_nonce, _initialChain));
    }

    function balances(
        uint256 _originalChain,
        bytes calldata _originalToken,
        address _account
    ) external view returns (uint256) {
        if (currentChain == _originalChain)
            return IERC721Metadata(abi.decode(_originalToken, (address))).balanceOf(_account);

        address issuedTokenAddress = getIssuedTokenAddress(_originalChain, _originalToken);

        if (!isIssuedTokenPublished(issuedTokenAddress)) return 0;
        return IERC721Metadata(issuedTokenAddress).balanceOf(_account);
    }
}
