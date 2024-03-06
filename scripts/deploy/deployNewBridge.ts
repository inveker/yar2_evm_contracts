import { Signer } from 'ethers'
import {
  BridgeERC1155__factory,
  BridgeERC20__factory,
  BridgeERC721__factory,
} from '../../typechain-types'

async function deployERC20Bridge(
  deployer: Signer,
  isProxyChain: boolean,
  validator: string,
  nativeName: string,
  nativeSymbol: string,
  nativeDecimals: number,
  nativeTransferGasLimit: number,
): Promise<string> {
  const contract = await new BridgeERC20__factory(deployer).deploy(
    isProxyChain, // _isProxyChain,
    validator, // _validator
    nativeName, // _nativeName
    nativeSymbol, // _nativeSymbol
    nativeDecimals, // _nativeDecimals
    nativeTransferGasLimit, // _nativeTransferGasLimit
  )
  return contract.address
}

async function deployERC721Bridge(
  deployer: Signer,
  isProxyChain: boolean,
  validator: string,
): Promise<string> {
  const contract = await new BridgeERC721__factory(deployer).deploy(
    isProxyChain, // _isProxyChain,
    validator, // _validator
  )
  return contract.address
}

async function deployERC1155Bridge(
  deployer: Signer,
  isProxyChain: boolean,
  validator: string,
): Promise<string> {
  const contract = await new BridgeERC1155__factory(deployer).deploy(
    isProxyChain, // _isProxyChain,
    validator, // _validator
  )
  return contract.address
}
