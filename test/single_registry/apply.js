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

contract('Single Registry', (accounts) => {
    describe('Function: apply', () => {
        const [applicant, proposer] = accounts;

        it('should allow a new listing to apply', async () => {
            const registry = await SingleRegistry.deployed();
            const subject = utils.getListingHash('Algebra');
            const listing = utils.getListingHash('nochallenge.net');

            await utils.as(applicant, registry.apply, listing, subject, paramConfig.minDeposit, '');

            // get the struct in the mapping
            const result = await registry.listings.call(listing);
            const subject_result = await registry.listingSubjects.call(listing, subject);

            // check that Application is initialized correctly
            assert.strictEqual(result[0].gt(0), true, 'challenge time < now');
            assert.strictEqual(result[1], false, 'whitelisted != false');
            assert.strictEqual(result[2], applicant, 'owner of application != address that applied');
            assert.strictEqual(
                result[3].toString(10),
                paramConfig.minDeposit.toString(10),
                'incorrect unstakedDeposit',
            );



            assert.strictEqual(subject_result[0].gt(0), true, 'subject challenge time < now');
            assert.strictEqual(subject_result[1], false, 'subject whitelisted != false');
            assert.strictEqual(subject_result[2].toString(10), paramConfig.minDeposit.toString(10), 'incorrect subject unstakedDeposit');

        });

        it('should not allow a listing to apply which has a pending application', async () => {
            const registry = await SingleRegistry.deployed();
            const subject = utils.getListingHash('Algebra');
            const listing = utils.getListingHash('nochallenge.net');

            // Verify that the application exists.
            const result = await registry.listings.call(listing);
            assert.strictEqual(result[2], applicant, 'owner of application != address that applied');

            try {
                await utils.as(applicant, registry.apply, listing, subject, paramConfig.minDeposit, '');
            } catch (err) {
                assert(utils.isEVMException(err), err.toString());
                return;
            }
            assert(false, 'application was made for listing with an already pending application');
        });

        describe('token transfer', async () => {
            const registry = await SingleRegistry.deployed();
            const token = Token.at(await registry.token.call());

            it('should revert if token transfer from user fails', async () => {
                const listing = utils.getListingHash('toFewTokens.net');
                const subject = utils.getListingHash('Algebra');

                // Approve the contract to transfer 0 tokens from account so the transfer will fail
                await token.approve(registry.address, '0', { from: applicant });

                try {
                    await utils.as(applicant, registry.apply, listing, subject, paramConfig.minDeposit, '');
                } catch (err) {
                    assert(utils.isEVMException(err), err.toString());
                    return;
                }
                assert(false, 'allowed application with not enough tokens');
            });

            after(async () => {
                const balanceOfUser = await token.balanceOf(applicant);
                await token.approve(registry.address, balanceOfUser, { from: applicant });
            });
        });

        it('should revert if the deposit amount is less than the minDeposit', async () => {
            const parameterizer = await Parameterizer.deployed();
            const registry = await SingleRegistry.deployed();
            const listing = utils.getListingHash('smallDeposit.net');
            const subject = utils.getListingHash('Algebra');
      
            const minDeposit = await parameterizer.get.call('minDeposit');
            const deposit = minDeposit.sub(10);
      
            try {
                await utils.as(applicant, registry.apply, listing, subject, deposit.toString(), '');
            } catch (err) {
              assert(utils.isEVMException(err), err.toString());
              return;
            }
            assert(false, 'allowed an application with deposit less than minDeposit');
          });

    });
});

