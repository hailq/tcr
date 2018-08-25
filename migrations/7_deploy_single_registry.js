/* global artifacts */

const SingleRegistry = artifacts.require('SingleRegistry.sol');
const Token = artifacts.require('EIP20.sol');
const Parameterizer = artifacts.require('Parameterizer.sol');
const DLL = artifacts.require('dll/DLL.sol');
const AttributeStore = artifacts.require('attrstore/AttributeStore.sol');
const PLCRVoting = artifacts.require('PLCRVoting.sol');

const fs = require('fs');

module.exports = (deployer, network, accounts) => {
  async function approveRegistryFor(addresses) {
    const token = await Token.deployed();
    const user = addresses[0];
    const balanceOfUser = await token.balanceOf(user);
    await token.approve(SingleRegistry.address, balanceOfUser, { from: user });
    if (addresses.length === 1) { return true; }
    return approveRegistryFor(addresses.slice(1));
  }

  deployer.link(DLL, SingleRegistry);
  deployer.link(AttributeStore, SingleRegistry);

  return deployer.then(async () => {
    const config = JSON.parse(fs.readFileSync('./conf/config.json'));
    let tokenAddress = config.token.address;

    if (config.token.deployToken) {
      tokenAddress = Token.address;
    }

    return deployer.deploy(
      SingleRegistry,
      tokenAddress,
      PLCRVoting.address,
      Parameterizer.address,
      config.name,
    );
  })
    .then(async () => {
      if (network === 'test' || network === 'coverage') {
        await approveRegistryFor(accounts);
      }
    }).catch((err) => { throw err; });
};
