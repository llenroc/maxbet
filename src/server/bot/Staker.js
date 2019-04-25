const Contract = require('../../contracts');
const _ = require('lodash');

var MAX_STAKER_IN_POOL = 15;
async function tryRejoinStaker(callback) {
  try {
    var stakersInPool = await Contract.get.stakersInPool();
    MAX_STAKER_IN_POOL = await Contract.get.getMaxStakersInPool();
    if (stakersInPool.length < MAX_STAKER_IN_POOL) {
      var stakers = await Contract.get.stakers();

      var candidates = stakers.filter(e => stakersInPool.indexOf(e) == -1 && e != '0x0000000000000000000000000000000000000000');
      if (candidates.length > 0) {
        var max = await Contract.get.stake(candidates[0]);
        var maxAddress = candidates[0];

        for (var i = 1; i < candidates.length; i++) {
          var candidate = await Contract.get.stake(candidates[i]);
          if (parseInt(candidate.amount) > parseInt(max.amount)) {
            max = candidate;
            maxAddress = candidates[i];
          }
        }

        var hash = await Contract.rejoinPool(maxAddress);
        await Contract.get.checkTx(hash);
      }
    }

    setTimeout(() => tryRejoinStaker(callback), 60000);
  }
  catch (ex) {
    callback && callback(ex);
  }
}

module.exports = tryRejoinStaker;