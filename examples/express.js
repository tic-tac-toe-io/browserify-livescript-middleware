'use strict';
var express = require('express');
var middleware = require(`${__dirname}/..`);
var port = process.env['PORT'] ? parseInt(process.env['PORT']) : 7000
const dest = '/tmp/work';
var app = express();
app.enable('trust proxy');
app.use('/js', middleware({
  src: `${__dirname}/assets`,
  dst: '/tmp/work'
}));
app.get('/', (req, res) => {
  res.setHeader('content-type', 'text/html');
  res.send(`
    <a href="view/example1">/example1</a><br>
    <a href="view/example2">/example2</a><br>
  `);
  res.end();
});
app.use('/view', (req, res, next) => {
  if (req.method == 'GET') {
    res.setHeader('content-type', 'text/html');
    res.send(`<html><body><script src="/js${req.url}.js"></script></body></html>`);
    res.end();
    return;
  }
  return next();
});
app.listen(port);
console.log(`listening port ${port}, please visit http://localhost:${port}`);
