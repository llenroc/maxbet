import Contract from '../contracts';
import utils from '../utils';

var store = {
  address: '',
  isShowLoginModal: false,
  isShowAccountModal: false,
  isShowJoinStakePoolModal: false,
  isShowManageStakeModal: false,
  isShowWithdrawModal: false,
  isShowHelpModal: false,
  isShowErrorModal: false,
  isShowChatBox: false,
  isAutoRoll: false,
  isRolling: false,
  errorMessage: '',
  changeToUpdateBalance: 0,
  changeToUpdateStake: 0,

  balance: 0,

  showError(msg) {
    store.isShowErrorModal = true;
    store.errorMessage = msg;
  },
  updateBalance() {
    if (store.address) {
      Contract.get.balance(store.address).then(v => {
        this.balance = utils.toTOMO(v);
      });
    }
  },
};

export default store;