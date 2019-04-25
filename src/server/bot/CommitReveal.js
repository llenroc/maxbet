const Contract = require('../../contracts');
const web3 = require('web3');
const db = require('../db');
const CryptoJS = require("crypto-js");
function betToString(bet) {
  return `${bet.index}: ${bet.player} | ${bet.round} | ${bet.number >= 10 ? bet.number : '0' + bet.number} | ${bet.isOver ? 'Over ' : 'Under'} | ${bet.amount}`;
}
async function generateCommitment() {
  var secret = web3.utils.randomHex(32);
  var commitment = web3.utils.soliditySha3({type: 'uint', value: secret});
  var encrypt = CryptoJS.AES.encrypt(secret, process.env.PASSWORD).toString();
  await db.put(commitment, encrypt);

  return commitment;
}

async function getSecret(commitment) {
  var encrypt = await db.get(commitment);
  var decryptBytes = CryptoJS.AES.decrypt(encrypt, process.env.PASSWORD);
  return decryptBytes.toString(CryptoJS.enc.Utf8);
}

async function getSecretForBet(bet) {
  try {
    if (bet) {
      console.log('> ', betToString(bet));
      var randIndex = await Contract.get.roundToRandIndex(bet.round);
      var rand = await Contract.get.rand(randIndex);
      var secret = rand.secret == '0' ? await getSecret(rand.commitment) : 0;

      return {
        round: secret ? bet.round : 0,
        secret
      };
    }
  } catch (ex) {
    console.log(ex);
  }

  return {
    round: 0,
    secret: 0
  }
}


module.exports = {
  generateCommitment,
  getSecretForBet
}