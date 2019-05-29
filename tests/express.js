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
app.listen(port);
console.log(`listening port ${port}, please visit http://localhost:${port}/js/test1.ls`);