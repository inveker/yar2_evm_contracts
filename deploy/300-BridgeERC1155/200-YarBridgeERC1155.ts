import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { EthersUtils } from '../../utils/EthersUtils'

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { ethers, deployments } = hre
  const { deploy, get } = deployments

  const signers = await ethers.getSigners()
  const validator = signers[0]

  const currentChain = EthersUtils.keccak256('YAR')
  const isProxyChain = true
  const IssuedERC1155Deployment = await get('IssuedERC1155')

  const deployment = await deploy('YarBridgeERC1155', {
    contract: 'BridgeERC1155',
    from: validator.address,
    args: [
      currentChain, // _currentChain,
      isProxyChain, // _isProxyChain,
      IssuedERC1155Deployment.address, // _issuedTokenImplementation,
      validator.address, // _validator
    ],
  })
}

deploy.tags = ['YarBridge', 'YarBridgeERC1155']
deploy.dependencies = ['IssuedERC1155']
export default deploy
