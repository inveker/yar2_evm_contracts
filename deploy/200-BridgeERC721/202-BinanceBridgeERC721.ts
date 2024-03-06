import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { EthersUtils } from '../../utils/EthersUtils'

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { ethers, deployments } = hre
  const { deploy, get } = deployments

  const signers = await ethers.getSigners()
  const validator = signers[0]

  const currentChain = EthersUtils.keccak256('BINANCE')
  const isProxyChain = false
  const IssuedERC721Deployment = await get('IssuedERC721')

  const deployment = await deploy('BinanceBridgeERC721', {
    contract: 'BridgeERC721',
    from: validator.address,
    args: [
      currentChain, // _currentChain,
      isProxyChain, // _isProxyChain,
      IssuedERC721Deployment.address, // _issuedTokenImplementation,
      validator.address, // _validator
    ],
  })
}

deploy.tags = ['BinanceBridge', 'BinanceBridgeERC721']
deploy.dependencies = ['IssuedERC721']
export default deploy
