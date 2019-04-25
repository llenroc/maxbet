const http = require('http');
const express = require('express');
const compression = require('compression');
const bot = require('./bot');
const db = require('./db');
require('dotenv').config()

const app = express();
app.use(compression());
if (process.env.WEBAPP == 'true') {
  app.use(express.static('./dist', {
    maxage: '1h'
  }));
}
else {
  app.get('/', (req, res) => {
    res.json({
      hi: ':)'
    });
  });
}


function botError(ex) {
  console.log('stop and try again', ex);
  bot.stop();
  setTimeout(() => {
    bot.start(botError);
  }, 2000);
}

if (process.env.PRIVATE_KEY && process.env.PASSWORD && process.env.MONGODB_URI) {
  http.createServer(app).listen(process.env.PORT || 3000, async (err) => {
    if (err) {
      console.log(err);
    }
    else {
      if (process.env.BOT == 'true') {
        try {
          await db.connect();
          bot.start(botError);
          console.log('Bot started');
        }
        catch (ex) {
          console.log(ex);
        }
      }
      console.log('Client app server running');
    }
  });
}
else {
  console.log('Cannot found PRIVATE_KEY, PASSWORD or MONGODB_URI');
}

