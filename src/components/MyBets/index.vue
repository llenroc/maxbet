<template>
  <div class="fs15">
    <table width="100%">
      <thead>
        <tr class="fs12">
          <th>PREDICTION</th>
          <th>LUCKY NUM</th>
          <th>BETS</th>
          <th>PAYOUT</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(e, i) in bets" :key="getKey(e, i)">
          <td>
            {{e.isOver ? 'Over' : 'Under'}} {{e.number}}
          </td>
          <td :style="{color: isWin(e) ? '#00d209' : '#ffffff'}">
            {{e.isFinished && e.luckyNumber >= 0 ? e.luckyNumber : ''}}
          </td>
          <td>
            {{e.amount}}
          </td>
          <td style="color: #f0c22a;">
            {{payout(e)}}
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script>

import Contract from '../../contracts';
import utils from '../../utils';
import _store from '../../store';
export default {
  data() {
    return {
      bets: [],
      luckyNumbers: {},
      store: _store,
      houseEdge: 1
    }
  },
  async created() {
    if (this.store.address) {
      var n = await Contract.get.totalNumberOfBets(this.store.address);
      n && this.getOldBet(n-1);
      this.subcribeNewBet();
      this.subcribeDrawBet();
    }
    this.houseEdge = await Contract.get.houseEdge();
  },
  destroyed() {
    clearTimeout(this.timeoutNewBet);
    clearTimeout(this.timeoutUpdateBet);
    Contract.get.offListenEvent('NewBet', 'mybets');
    Contract.get.offListenEvent('DrawBet', 'mybets');
  },
  methods: {
    parseBet(bet) {
      return {
        index: parseInt(bet.index),
        amount: utils.toTOMO(bet.amount),
        number: parseInt(bet.number),
        isOver: bet.isOver,
        round: parseInt(bet.round),
        isFinished: bet.isFinished,
        luckyNumber: parseInt(bet.luckyNumber),
        player: bet.player.toLowerCase()
      }
    },
    getKey(e, i){
      return Math.random() + "-" + i;
    },
    isWin(bet) {
      if (bet.luckyNumber >= 0 && bet.isFinished) {
        if (bet.isOver) {
          return bet.number < bet.luckyNumber;
        }
        else {
          return bet.number > bet.luckyNumber;
        }
      }
      return false;
    },
    payout(bet) {
      var multi = 0
      if (!bet.isFinished) {
        return '';
      }
      if(bet.isOver) {
        if (bet.number < bet.luckyNumber) {
          multi = Math.floor((100000 - this.houseEdge * 1000) / (99 - bet.number)) / 1000;
        }
      }
      else if (bet.number > bet.luckyNumber) {
        multi = Math.floor((100000 - this.houseEdge * 1000) / bet.number) / 1000;
      }

      var result = Math.floor(bet.amount * multi * 100) / 100;
      return result > 0 ? result : '-';
    },
    subcribeNewBet() {
      Contract.get.onListenEvent('NewBet', value => {
        if (value.player.toLowerCase() != this.store.address.toLowerCase()) return;
        value.isFinished = false;
        value.luckyNumber = 0;
        var bet = this.parseBet(value);
        var find = this.bets.find(e => e.index == bet.index);
        if (!find) {
          this.bets.unshift(bet);
          this.bets = this.bets.slice(0, 13);
        }
      }, 'mybets');
    },
    subcribeDrawBet() {
      Contract.get.onListenEvent('DrawBet', value => {
        if (value.player.toLowerCase() != this.store.address.toLowerCase()) return;
        value.player = value.player.toLowerCase();
        var bet = this.bets.find(e => e.player == value.player);
        if (bet) {
          bet.isFinished = true;
          bet.luckyNumber = parseInt(value.luckyNumber);
        }
      }, 'mybets');
    },
    async getOldBet(index) {
      if (index < 0 || this.bets.length >= 13) return;

      var bet = await Contract.get.betOf(this.store.address, index)
      bet.index = index;
      if (bet && bet.player !== '0x0000000000000000000000000000000000000000') {
        this.bets.push(bet);
        this.getOldBet(index - 1);
      }
    },
  }
}
</script>

<style scoped>
table {
  border-spacing: 0
}
table thead tr th {
  padding-top: 4px;
  padding-bottom: 10px;
}
table tbody tr td {
  padding-top: 4px;
  padding-bottom: 4px;
}
table tbody tr:nth-of-type(odd) {
  background: rgba(256, 256, 256, 0.06)
}
</style>
