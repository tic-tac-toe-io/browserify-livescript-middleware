'use strict';
var express = require('express');
var livescript_middleware = require(`${__dirname}/..`);
var port = process.env['PORT'] ? parseInt(process.env['PORT']) : 7000
const dest = '/tmp/work';
var app = express();
app.enable('trust proxy');
app.use('/js', livescript_middleware({
  src: `${__dirname}/scripts`,
  dst: '/tmp/work',
  compress: true
}));
app.get('/', (req, res) => {
  res.setHeader('content-type', 'text/html');
  res.send(`
    <a href="view/aaa/test1">/aaa/test1</a><br>
    <a href="view/aaa/test2">/aaa/test2</a><br>
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
console.log(`listening port ${port}, please visit http://localhost:${port}/js/test1.ls`);