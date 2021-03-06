# browserify-livescript-middleware

The middleware to process [livescript](http://livescript.net/) files into a single javascript file for [Connect JS](http://www.senchalabs.org/connect/) framework and by extension the [Express JS](http://expressjs.com/).

**LiveScript** is a language which compiles to **JavaScript**. It has a straightforward mapping to JavaScript and allows you to write expressive code devoid of repetitive boilerplate. While LiveScript adds many features to assist in functional style programming, it also has many improvements for object oriented and imperative programming.

Check out **[livescript.net](http://livescript.net)** for more information, examples, usage, and a language reference.


## Try

```text
$ npm install @tic-tac-toe/browserify-livescript-middleware
$ npm install express
$ PORT=8000 DEBUG=browserify-livescript-middleware node ./node_modules/@tic-tac-toe/browserify-livescript-middleware/examples/express.js
```

Then, open chrome with devtool to visit http://localhost:7000/view/example1, and see its source tab:

![](./docs/chrome_devtool_source_map.png)


## Usage

The middleware serves Livescript compilation, javascript bundling/compression, and static javascript files, so its usage is very simple. Just create a middleware instance with the given options:

- `src` directory of livescript source files
- `dst` directory of produced javascript files

Here is full example:

```javascript
var bls = require('@tic-tac-toe/browserify-livescript-middleware');
var app = express();
app.enable('trust proxy');
app.use('/js', bls({
    src: `${__dirname}/scripts`,
    dst: '/tmp/work'
}));
app.listen(8000);
```


## livescript-middleware? Why?

This project was originally forked from [livescript-middleware](https://www.npmjs.com/package/livescript-middleware). But, after making some changes, we found there are too many changes to be merged to original module. Then, we decided to create a new middleware to meet all of our requirements. Please see [Why](./docs/WHY.md) for more rationales.


## Todos

- [ ] support koa2
- [ ] support fastly
- [ ] write a simple `examples/express/index.js` with ES6 to test/demonstrate this middleware
- [ ] test `examples/koa/index.js` with [koa](https://github.com/koajs/koa)
- [x] use a forked livescript (https://github.com/ischenkodv/LiveScript/commit/7ae73cb263cb55ae32e44fddae81510aa4401679) with correct source map support (upgrade `source-map-support` from 0.3.2 to 0.5.11)
- [ ] move `src/liveify` to a standalone transform module, similar to [liveify](https://www.npmjs.com/package/liveify), maybe `liveify-next`