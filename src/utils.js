const Web3 = require('web3');

module.exports = {
  toTOMO(bigNum) {
    var v = Web3.utils.fromWei(bigNum.toString(), 'ether');
    v = parseFloat(v);
    return Math.floor(v * 100) / 100
  }
}