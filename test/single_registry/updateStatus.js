/* eslint-env mocha */
/* global assert contract artifacts */
const SingleRegistry = artifacts.require('SingleRegistry.sol');

const fs = require('fs');
const BN = require('bignumber.js');

const config = JSON.parse(fs.readFileSync('./conf/config.json'));
const paramConfig = config.paramDefaults;

const utils = require('../utils.js');

const bigTen = number => new BN(number.toString(10), 10);

contract('SingleRegistry', (accounts) => {
    describe('Function: updateStatus', () => {
        const [applicant, challenger] = accounts;
        const minDeposit = bigTen(paramConfig.minDeposit);

        it('should whitelist listing if apply stage ended without a challenge', async () => {
            const registry = await SingleRegistry.deployed();
            const listing = utils.getListingHash('whitelist.io');
            const subject = utils.getListingHash('Algebra');

            await utils.addToSubjectWhitelist(listing, subject, minDeposit, applicant);

            const result = await registry.isSubjectWhitelisted.call(listing, subject);

            assert.strictEqual(result, true, 'Listing should have been whitelisted');
        })

        it('should not whitelist a listing that is still pending an application', async () => {
            const registry = await SingleRegistry.deployed();
            const listing = utils.getListingHash('tooearlybuddy.io');
            const subject = utils.getListingHash('Algebra');

            await utils.as(applicant, registry.apply, listing, subject, minDeposit, '');

            try {
                await utils.as(applicant, registry.updateStatus, listing);
            } catch (err) {
                assert(utils.isEVMException(err), err.toString());
                return;
            }
            assert(false, 'Listing should not have been whitelisted');
        });

        it('should not whitelist a listing that is currently being challenged', async () => {
            const registry = await SingleRegistry.deployed();
            const listing = utils.getListingHash('dontwhitelist.io');
            const subject = utils.getListingHash('Algebra');

            await utils.as(applicant, registry.apply, listing, subject, minDeposit, '');
            await utils.as(challenger, registry.challenge, listing, '');

            try {
                await registry.updateStatus(listing);
            } catch (err) {
                assert(utils.isEVMException(err), err.toString());
                return;
            }
            assert(false, 'Listing should not have been whitelisted');
        });

        it('should not whitelist a listing that failed a challenge', async () => {
            const registry = await SingleRegistry.deployed();
            const listing = utils.getListingHash('dontwhitelist.net');
            const subject = utils.getListingHash('Algebra');
      
            await utils.as(applicant, registry.apply, listing, subject, minDeposit, '');
            await utils.as(challenger, registry.challenge, listing, '');
      
            const plcrComplete = paramConfig.revealStageLength + paramConfig.commitStageLength + 1;
            await utils.increaseTime(plcrComplete);
      
            await registry.updateStatus(listing);
            const result = await registry.isSubjectWhitelisted(listing, subject);
            assert.strictEqual(result, false, 'Listing should not have been whitelisted');
          });
    })
})