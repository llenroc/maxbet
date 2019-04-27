<template>
  <div class="modal animated fadeIn fast">
    <div class="modal-container" style="margin-top: 100px;">
      <button class="modal-close-btn" @click="() => store.isShowSettingModal = false" />
      <div class="modal-title">
        Setting
      </div>
      <div v-if="!msg">
        <div class="input mt30">
          <label>Payout Level:</label>
          <input style="width: 55%" v-model="payout" type="number" placeholder="value from 10 - 100"/>
          <button style="width: 30%" class="btn secondary" @click="setPayout">Submit</button>
        </div>
      </div>
      <div v-else>
        <span :style="{color: !isError ? 'green' : 'red'}">{{msg}}</span>
        <button v-if="isError" class="btn primary mt10" @click="tryAgain">Try Again</button>
      </div>
    </div>
  </div>
</template>

<script>
import QRCode from '@xkeshi/vue-qrcode';
import _store from '../../store';
import Contract from '../../contracts';
import utils from '../../utils';

export default {
  components: {
    QRCode
  },
  data() {
    return {
      store: _store,
      payout: '',
      msg: '',
      isError: false
    }
  },
  async created() {
    this.payout = await Contract.get.getPrizePerBetLevel();
  },
  methods: {
    tryAgain() {
      this.msg = "";
      this.isError = false;
    },
    async setPayout() {
      if (this.isSubmitting) return;
      this.isSubmitting = true;
      try {
        if (this.payout < 10 || this.payout > 100) {
          this.msg = `Value from 10 to 1000`;
          this.isError = true;
          return;
        }
        var hash = await Contract.setPrizeLevel(this.payout);
        this.isSubmitting = false;
        this.msg = 'Your setting is in processing.';
        var tx = await Contract.get.checkTx(hash);
        this.msg = `Done`;
      }
      catch(ex) {
        this.isSubmitting = false;
        if (ex.toString().toLowerCase().indexOf('user denied transaction signature') >= 0) {
          return;
        }
        console.error(ex);
        this.msg = 'Error, Cannot setup. Please try again.';
        this.isError = true;
      }
    }
  }
}
</script>

<style scoped>
.join-qr {
  width: 130px;
  height: 130px;
  margin: auto;
}

.join-qr canvas {
    height: 130px;
    width: 130px;
}

.join-qr-description {
  font-family: monospace;
  line-height: 1;
  margin-top: 10px;
  font-size: 15px;
  color: gray;
  text-align: center;
}

.remaining-stake {
  color: red;
  font-family: sans-serif;
  font-size: 12px !important;
  margin-top: -10px;
}
</style>
