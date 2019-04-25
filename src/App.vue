<template>
  <div id="app">
    <LoginModal v-if="store.isShowLoginModal" />
    <AccountModal v-if="store.isShowAccountModal" />
    <JoinStakePoolModal v-if="store.isShowJoinStakePoolModal" />
    <ManageStakeModal v-if="store.isShowManageStakeModal" />
    <WithdrawStakePoolModal v-if="store.isShowWithdrawModal" />
    <HelpModal v-if="store.isShowHelpModal" />
    <ErrorModal v-if="store.isShowErrorModal" />
    <Home />
    <ChatBox/>
  </div>
</template>

<script>
import Home from './components/Home';
import LoginModal from './components/LoginModal';
import AccountModal from './components/AccountModal';
import JoinStakePoolModal from './components/JoinStakePoolModal';
import ManageStakeModal from './components/ManageStakeModal';
import WithdrawStakePoolModal from './components/WithdrawStakePoolModal';
import HelpModal from './components/HelpModal';
import ErrorModal from './components/ErrorModal';
import ChatBox from './components/ChatBox';

import store from './store';
import Contract from './contracts';

export default {
  name: 'app',
  components: {
    Home,
    LoginModal,
    AccountModal,
    JoinStakePoolModal,
    ManageStakeModal,
    WithdrawStakePoolModal,
    HelpModal,
    ErrorModal,
    ChatBox
  },
  data() {
    return {
      store: store
    }
  },
  created() {
    if (window.web3 && window.web3.currentProvider) {
      if (window.web3.currentProvider.isTomoWallet) {
        Contract.login({
          tomowallet: true
        }, (err, address) => {
          console.log(address);
          store.address = address;
        });
      }
      else if (!window.web3.currentProvider.isMetaMask) {
        Contract.login({
          metamask: true
        }, (err, address) => {
          console.log(address);
          store.address = address;
        });
      }
    }
    else {
      Contract.login({
        address: sessionStorage.address,
        privateKey: sessionStorage.privateKey,
        hdpath: sessionStorage.hdpath,
        metamask: localStorage.metamask
      }, (err, address) => {
        console.log(address);
        store.address = address;
      });
    }
  }
}
</script>