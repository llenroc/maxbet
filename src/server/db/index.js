const mongoose = require('mongoose');

const KeyValue = mongoose.model('KeyValue', {
  key: {
    type: String,
    unique: true,
    index: true
  },
  value: String
});

module.exports = {
  connect() {
    return new Promise((resolve, reject) => {
      console.log('Try to connect', process.env.MONGODB_URI);
      mongoose.connect(process.env.MONGODB_URI, {
        useNewUrlParser: true,
        useCreateIndex: true
      }, (err) => {
        if (err) return reject(err);
        else return resolve(resolve);
      });
    })
  },
  put: async (key, value) => {
    var a = await KeyValue.create({
      key: key,
      value: value
    });
    var v = await KeyValue.findOne({key: key});
    if (v.value == value) {
      return value;
    }
    else {
      throw new Error('Cannot save to database');
    }
  },
  get: async (key) => {
    var v = await KeyValue.findOne({key: key});
    if (!v) throw new Error("Cannot found value with key", key);
    return v.value;
  }
}