<template>
  <div class="home">
    <div class="home-container">
      <div class="home-game">
        <Navbar ref="nav"/>
        <div class="home-current-game">
          <YourBet :isOver="bet.isOver" :number="bet.number" :amount="bet.amount"/>
          <LuckyNumber :number="luckyNumber" :isAutoRoll="store.isAutoRoll" :isDrawing="store.isRolling"/>
        </div>
        <Bet ref="bet" />
        <RollButton class="roll-btn"
          :isRolling="store.isRolling"
          @click="roll"/>
        <div v-if="showResult" class="result-modal animated fadeIn" @click="showResult = false">
          <button class="modal-close-btn" @click="showResult = false" />
          <div>
            <div class="icon">{{iconResult}}</div>
            <div class="result">{{isWin(bet) ? 'You won' : 'You lose'}}</div>
            <div class="payout green">{{isWin(bet) ? `+ ${payout(bet)}` : ''}}</div>
          </div>
        </div>
      </div>
      <div class="home-gameinfo">
        <GameInfo />
      </div>
    </div>
    <Footer />
  </div>
</template>

<script>
import RollButton from '../RollButton';
import Navbar from '../Navbar';
import LuckyNumber from '../LuckyNumber';
import GameInfo from './GameInfo';
import YourBet from '../YourBet';
import Bet from '../Bet';
import _store from '../../store';
import Contract from '../../contracts';
import Footer from '../Footer';
import utils from '../../utils';
export default {
  components: {
    RollButton,
    Navbar,
    LuckyNumber,
    YourBet,
    Bet,
    GameInfo,
    Footer
  },
  data() {
    return {
      store: _store,
      luckyNumber: 0,
      showResult: false,
      iconResult: '',
      houseEdge: 1,
      bet: {
        index: 0,
        isOver: false,
        number: 0,
        amount: 0,
        round: 0,
        isFinished: false,
        luckyNumber: 0
      }
    }
  },
  async created() {
    this.houseEdge = await Contract.get.houseEdge();
  },
  mounted() {
    this.updateBet();
    this.subcribeNewBet();
    this.subcribeDrawBet();
    Contract.get.onListenEvent('NEW_BLOCK', e => this.tryGetMyBet(this.store.address), 'HOME_NEW_BLOCK');
    window.scrollTo(0, 0);
  },
  watch: {
    'store.address': {
      handler() {
        this.luckyNumber = 0;
        this.bet = {
          index: 0,
          isOver: false,
          number: 0,
          amount: 0,
          round: 0,
          isFinished: false,
          luckyNumber: 0
        }
        clearTimeout(this.timeoutRoll);
        clearTimeout(this.timeoutCheckRoll);
        this.updateBet();
      }
    }
  },
  destroyed() {
    clearTimeout(this.timeoutRoll);
    clearTimeout(this.timeoutCheckRoll);
    Contract.get.offListenEvent('NEW_BLOCK', 'HOME_NEW_BLOCK');
    Contract.get.offListenEvent('NewBet', 'HOME_NEW_BET');
    Contract.get.offListenEvent('DrawBet', 'HOME_DRAW_BET');
  },
  methods: {
    updateBet() {
      clearTimeout(this.timeoutRoll);
      this.tryGetMyBet(this.store.address);
    },
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
    winIcon() {
      var icons = ['🤑','🏆','🚀','🔥','🎁','🤩','🙌','🤟','👏','🍻'];
      return icons[Math.round(Math.random() * 1000) % icons.length];
    },
    loseIcon() {
      var icons = ['😭','😔','😢','💔'];
      return icons[Math.round(Math.random() * 1000) % icons.length];
    },
    subcribeNewBet() {
      Contract.get.onListenEvent('NewBet', value => {
        value.isFinished = false;
        value.luckyNumber = 0;
        var bet = this.parseBet(value);
      }, 'HOME_NEW_BET');
    },
    subcribeDrawBet() {
      Contract.get.onListenEvent('DrawBet', value => {
        var bet = this.parseBet(value);
        this.processUpdateBet(bet);
      }, 'HOME_DRAW_BET');
    },
    processUpdateBet(bet) {
      if (!bet) return;

      if (bet.player !== this.store.address) return;
      if (this.bet.index == bet.index && this.bet.isFinished == bet.isFinished) return;

      if (bet.isFinished) {
        if (this.bet.index > 0 && bet.amount > 0) {
          this.showResult = true;
          this.iconResult = this.isWin(bet) ? this.winIcon() : this.loseIcon();
        }
        this.store.isRolling = false;
        this.luckyNumber = bet.luckyNumber;
        this.$refs.nav && this.$refs.nav.refreshBalance(true);
        this.$refs.bet && this.$refs.bet.refershAmount();
        if (this.store.isAutoRoll) {
          clearTimeout(this.timeoutRoll);
          this.timeoutRoll = setTimeout(() => this.store.isAutoRoll && this.roll(), 1700);
        }
      }
      else {
        this.store.isRolling = true;
      }

      this.bet = bet;
    },
    async tryGetMyBet(address) {
      if (this.isGetingMyBet) return;
      if (!address) return;
      var bet = null;
      try {
        this.isGetingMyBet = true;
        bet = await Contract.get.lastBet(address);
        this.isGetingMyBet = false;
        this.processUpdateBet(bet);
      }
      catch (ex) {
        return;
      }
    },
    async submitBet() {
      try {
        clearTimeout(this.timeoutCheckRoll);

        this.timeoutCheckRoll = setTimeout(async () => {
          var bet = await Contract.get.bet(betIndex);
          this.store.isRolling = bet.isFinished ? false : this.store.isRolling;
        }, 30000);
        debugger;

        var hash = await Contract.placeBet(this.bet.amount, this.bet.number, this.bet.isOver);
        this.$refs.nav && this.$refs.nav.addBalance(-this.bet.amount, false, true);
        var tx = await Contract.get.checkTx(hash);
        this.$refs.bet && this.$refs.bet.refershAmount();
        this.updateBet();

        clearTimeout(this.timeoutCheckRoll);
      }
      catch (ex) {
        this.betError(ex);
      }
    },
    betError(ex) {
      console.error(ex);
      clearTimeout(this.timeoutCheckRoll);

      this.store.isRolling = false;
      var errMsg = ex.toString().toLowerCase();
      if (errMsg.indexOf('user denied transaction signature') >= 0 || errMsg.indexOf('cancelled') >= 0) {
        return;
      }
      if (errMsg.indexOf('revert') >= 0) {
        this.$refs.nav.addBalance(this.bet.amount, false, true);
        window.handleError('Roll Error, please refresh and try again.');
        return;
      }

      window.handleError(ex);
    },
    async roll() {
      clearTimeout(this.timeoutRoll);
      this.showResult = false;
      if (!this.store.address) return this.store.showError('Login to play, please');
      if (this.store.isRolling) return;

      this.store.isRolling = true;

      var newBet = this.$refs.bet.get();
      var balance = this.$refs.nav.currentBalance();
      if (balance < newBet.amount) {
        this.store.isRolling = false;
        return this.store.showError('You have not enough TOMO for this bet');
      }
      if (newBet.amount <= 0) {
        this.store.isRolling = false;
        return this.store.showError('Your bet is 0');
      }

      this.bet.isOver = newBet.isOver;
      this.bet.number = newBet.number;
      this.bet.amount = newBet.amount;

      this.submitBet();

    }
  }
}
</script>

<style scoped>
.home {
  min-height: 100vh;
  /* padding-top: 10px; */
  /* background-image: url(./bg.png); */
  /* background-size: cover; */
  background: #05042c;
}
.home-current-game {
  padding: 0 50px;
}

@media (min-width: 768px) {
  .home-container {
    max-width: 1000px;
    margin: auto;
    display: flex;
    justify-content: center;
  }
  .home-current-game {
    padding: 0 20px;
  }

  .home-game {
    width: 410px;
  }

  .home-gameinfo {
    width: 500px;
    margin-top: 65px;
  }
}

.roll-btn {
  overflow: hidden;
  padding: 20px 15px 10px 15px;
}

.result-modal {
  position: fixed;
  top: 47%;
  left: 50%;
  width: 150px;
  height: 150px;
  transform: translate(-50%, -50%);
  text-align: center;
  font-size: 50px;
  bottom: 0;
  background: #ffffff;
  z-index: 999;
  border-radius: 20px;
  padding: 15px;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0px 10px 100px black;
}

.result-modal .icon {
  line-height: 1.1;
  margin-top: 15px;
}

.result-modal .result {
  font-size: 25px;
}

.result-modal .payout {
  font-size: 40px;
}

</style>
