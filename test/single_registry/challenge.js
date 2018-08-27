/* eslint-env mocha */
/* global assert contract artifacts */
const SingleRegistry = artifacts.require('SingleRegistry.sol');
const Parameterizer = artifacts.require('Parameterizer.sol');
const Token = artifacts.require('EIP20.sol');

const fs = require('fs');
const BN = require('bignumber.js');

const config = JSON.parse(fs.readFileSync('./conf/config.json'));
const paramConfig = config.paramDefaults;

const utils = require('../utils.js');

const bigTen = number => new BN(number.toString(10), 10);

contract('SingleRegistry', (accounts) => {
    describe('Function: challenge', () => {
        const [applicant, challenger, voter, proposer] = accounts;

        it('should successfully challenge an application', async () => {
            const registry = await SingleRegistry.deployed();
            const token = Token.at(await registry.token.call());
            const listing = utils.getListingHash('failure.net');
            const subject = utils.getListingHash('Algebra');

            const challengerStartingBalance = await token.balanceOf.call(challenger);

            await utils.as(applicant, registry.apply, listing, subject, paramConfig.minDeposit, '');
            await utils.challengeSubjectAndGetPollID(listing, subject, challenger);
            await utils.increaseTime(paramConfig.commitStageLength + paramConfig.revealStageLength + 1);
            await registry.updateStatus(listing);

            const isWhitelisted = await registry.isSubjectWhitelisted.call(listing, subject);
            assert.strictEqual(isWhitelisted, false, 'An application which should have failed succeeded');

            const challengerFinalBalance = await token.balanceOf.call(challenger);
            // Note edge case: no voters, so challenger gets entire stake
            const expectedFinalBalance =
                challengerStartingBalance.add(new BN(paramConfig.minDeposit, 10));
            assert.strictEqual(
                challengerFinalBalance.toString(10), expectedFinalBalance.toString(10),
                'Reward not properly disbursed to challenger',
            );
        });

        it('should successfully challenge a listing', async () => {
            const registry = await SingleRegistry.deployed();
            const token = Token.at(await registry.token.call());
            const listing = utils.getListingHash('failure.net');
            const subject = utils.getListingHash('Algebra');

            const challengerStartingBalance = await token.balanceOf.call(challenger);

            await utils.addToSubjectWhitelist(listing, subject, paramConfig.minDeposit, applicant);

            await utils.challengeSubjectAndGetPollID(listing, subject, challenger);
            await utils.increaseTime(paramConfig.commitStageLength + paramConfig.revealStageLength + 1);
            await registry.updateStatus(listing);

            const isWhitelisted = await registry.isSubjectWhitelisted.call(listing, subject);
            assert.strictEqual(isWhitelisted, false, 'An application which should have failed succeeded');

            const challengerFinalBalance = await token.balanceOf.call(challenger);
            // Note edge case: no voters, so challenger gets entire stake
            const expectedFinalBalance =
              challengerStartingBalance.add(new BN(paramConfig.minDeposit, 10));
            assert.strictEqual(
              challengerFinalBalance.toString(10), expectedFinalBalance.toString(10),
              'Reward not properly disbursed to challenger',
            );
          });

    });
});
