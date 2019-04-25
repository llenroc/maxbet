import Vue from 'vue'
import App from './App.vue'
import './styles/style.css'
import './styles/aminated.css'
import './styles/modal.css'
import './styles/button.css'
import './styles/input.css'
import store from './store'

Vue.config.productionTip = false
window.handleError = (ex) => {
  store.showError(ex && ex.toString() || 'Have an error, refresh and try again please!');
}
new Vue({
  render: h => h(App),
}).$mount('#app')
