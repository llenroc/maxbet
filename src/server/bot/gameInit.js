const Contract = require('../../contracts');
const CommitReveal = require('./CommitReveal');

module.exports = async function() {
  try {
    var v = await Contract.get.getLastRand();
    var randIndexForNextRound = await Contract.get.randIndexForNextRound();
    if (randIndexForNextRound > parseInt(v.index)) {
      throw new Error('Have not ready');
    }
    if (v.commitment == '0x0000000000000000000000000000000000000000000000000000000000000000') {
      throw new Error('Have not ready');
    }

    if (v.secret != 0) {
      throw new Error('Have not ready');
    }
  }
  catch (ex) {
    for (var i = 0; i < 10; i++) {
      var commitment = await CommitReveal.generateCommitment();
      console.log('Init game:');
      console.log(`   Commitment: ${commitment}`);
      var hash = await Contract.commit(commitment);
      var v = await Contract.get.checkTx(hash);
    }
  }
}