const abi = require('./abi');

module.exports = {
  ABI: abi,

  RPC: process.env.NODE_ENV === 'production' ?
    'https://rpc.tomochain.com' :
    'https://testnet.tomochain.com',

  RPC_READ: process.env.NODE_ENV === 'production' ?
    'https://rpc.tomochain.com' :
    'https://testnet.tomochain.com',

  RPC_READ_SOCKET: process.env.NODE_ENV === 'production' ?
    'wss://ws.tomochain.com' :
    'wss://testnet.tomochain.com/ws',

  NETWORK_ID: process.env.NODE_ENV === 'production' ? '88' : '89',
  ADDRESS: process.env.NODE_ENV === 'production' ?
    '0x305f55a3d55e01eed0b2b33fa1fd035ac5d086f7' :
    '0x2f1c28f3eb9c7626225ff12b269d1f4bec83e27f'
}

// module.exports = {
//   ABI: abi,

//   RPC: process.env.NODE_ENV === 'production' ?
//     'https://rpc.tomochain.com' :
//     'https://testnet.tomochain.com',

//   RPC_READ: process.env.NODE_ENV === 'production' ?
//     'https://rpc-fullnode.tomochain.com' :
//     'https://testnet.tomochain.com',

//   RPC_READ_SOCKET: process.env.NODE_ENV === 'production' ?
//     'wss://ws.tomochain.com' :
//     'wss://testnet.tomochain.com/ws',

//   NETWORK_ID: process.env.NODE_ENV === 'production' ? '88' : '89',
//   ADDRESS: process.env.NODE_ENV === 'production' ?
//     '0x3b9d9e97ba0e2b47fe643148cdf98e943e141049' :
//     '0xed4cfef5cd9f4db81392fef171ffe552fb7fbe9e'
// }