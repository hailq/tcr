const Registry = artifacts.require('Registry.sol');
const utils = require('./utils');

const fs = require('fs');
const BN = require('bignumber.js');

const config = {
    "paramDefaults": {
        "minDeposit": 10000000000000000000,
        "pMinDeposit": 100000000000000000000,
        "applyStageLength": 10,
        "pApplyStageLength": 20,
        "commitStageLength": 10,
        "pCommitStageLength": 20,
        "revealStageLength": 10,
        "pRevealStageLength": 20,
        "dispensationPct": 50,
        "pDispensationPct": 50,
        "voteQuorum": 50,
        "pVoteQuorum": 50
    }
}

const paramConfig = config.paramDefaults;

contract('Single Registry', (accounts) => {
    describe('Function: Create new subject', () => {
        it('should add a new subjects to the subject list', async () => {

            let acc = accounts[0];
            const registry = await Registry.deployed();
            const newSubject = "Test Subject";

            await registry.newSubject(newSubject, { from: acc });

            assert.equal(
                (await registry.subjects.call(2)), utils.getListingHash(newSubject), 'The new subject was added',
            );
        })

        it('should validate the subject name', async () => {
            
            let acc = accounts[0];
            const registry = await Registry.deployed();
            const newSubject = "Test Subject";

            
        })
    })
})