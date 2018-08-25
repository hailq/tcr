/* eslint-env mocha */
/* global assert contract artifacts */
const Parameterizer = artifacts.require('./Parameterizer.sol');
const SingleRegistry = artifacts.require('SingleRegistry.sol');
const Token = artifacts.require('EIP20.sol');

const fs = require('fs');
const BN = require('bignumber.js');

const config = JSON.parse(fs.readFileSync('./conf/config.json'));
const paramConfig = config.paramDefaults;

const utils = require('../utils.js');

contract('Registry', (accounts) => {
  describe('Function: apply', () => {
    const [applicant, proposer] = accounts;

    it('should allow a new listing to apply', async () => {
      const registry = await SingleRegistry.deployed();
      const subject = utils.getListingHash('Algebra');
      const listing = utils.getListingHash('nochallenge.net');

      await utils.as(applicant, registry.apply, listing, subject, paramConfig.minDeposit, '');

      // get the struct in the mapping
      const result = await registry.listings.call(listing);
      // check that Application is initialized correctly
      assert.strictEqual(result[0].gt(0), true, 'challenge time < now');
      assert.strictEqual(result[1], false, 'whitelisted != false');
      assert.strictEqual(result[2], applicant, 'owner of application != address that applied');
      assert.strictEqual(
        result[3].toString(10),
        paramConfig.minDeposit.toString(10),
        'incorrect unstakedDeposit',
      );
    });
  });
});

