#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#

/**
 * Module dependencies.
 */
require! <[fs url path]>
require! <[extend livescript mkdirp browserify through2]>
{minify} = require \uglify-es
DBG = (require \debug) \browserify-livescript-middleware


##
# javascript codes:
#
#   ```
#   var app = express();
#   app.enable('trust proxy');
#   app.use('/js', livescript_middleware({
#     src: `${__dirname}/scripts`,
#     dst: '/tmp/work',
#     compress: true
#   }));
#   ```
#
# When browser requests the javascript file with following URL:
#
#     http://127.0.0.1:6000/js/aaa/bbb/hello.js?forced=true&sourceMap=embedded
#
# The fields of `req` in middleware handler are listed as below
#
#     - req.originalUrl: `/js/aaa/bbb/hello.js?forced=true&sourceMap=embedded`
#     - req.baseUrl    : `/js`
#     - req.url        : `/aaa/bbb/hello.js?forced=true&sourceMap=embedded`
#     - req.path       : `/aaa/bbb/hello.js`
#     - req.get('host'): `127.0.0.1:6000`
#     - req.protocol   : `http`
#     - req.query      : {forced: 'true', sourceMap: 'embedded'}
#
#     - url.parse(req.originalUrl).pathname: `/js/aaa/bbb/hello.js`
#     - url.parse(req.url).pathname        : `/aaa/bbb/hello.js`
#
# And, when browser requests the javascript file behind Nginx (and the `trust proxy` in express-js is enabled),
# the url and its components are listed as below:
#
#     https://test.example.com/js/aaa/bbb/hello.js?forced=true&sourceMap=embedded
#
#     - req.originalUrl: (same as above)
#     - req.baseUrl    : (same as above)
#     - req.url        : (same as above)
#     - req.path       : (same as above)
#     - req.get('host'): `test.example.com`
#     - req.protocol   : `https`
#     - req.query      : (same as above)
#
#     - url.parse(req.originalUrl).pathname: (same as above)
#     - url.parse(req.url).pathname        : (same as above)
#
#
#

const DEFAULTS =
  src: null
  dst: null

const ENOENT = \ENOENT

const LIVESCRIPT_COMPILER_OPTIONS =
  bare: yes
  map: \embedded

const BROWSERIFY_OPTIONS =
  debug: yes                              # for source-map support
  transform: <[browserify-livescript]>
  extensions: <[.ls]>

const UGLIFY_OPTIONS =
  compress: {passes: 2}
  mangle: true
  output: {beautify: false, preamble: "/* uglified */"}


MIDDLEWARE_CURRYING = (m, req, res, next) -->
  return next! unless req.method in <[GET HEAD]>
  {pathname} = tokens = url.parse req.url
  return m.process-source tokens, req, res, next if /.js$/.test pathname
  return m.process-source-map pathname, req, res, next if /.js.map$/.test pathname
  return next!


##
# Inspired by https://github.com/ysulyma/livescript-middleware/blob/master/index.ls
#
class SourceHandler
  (@m, @tokens, @req, @res, @next) ->
    {pathname} = tokens
    @pathname = pathname
    {protocol, query, baseUrl} = req
    {forced, raw, sourceMap} = query
    @hostname = hostname = req.get \host
    @site = site = "#{protocol}://#{hostname}#{baseUrl}"
    DBG "source-handler(): site: %s", site
    DBG "source-handler(): pathname: %s", pathname
    @embedded-source-map = no
    @embedded-source-map = yes if sourceMap? and sourceMap is \embedded
    @forced-compilation = no
    @forced-compilation = yes if forced? and forced is \true
    @keeping-raw-source = no
    @keeping-raw-source = yes if raw? and raw is \true
    {embedded-source-map, forced-compilation, keeping-raw-source} = @
    DBG "source-handler(): opts: %o", {embedded-source-map, forced-compilation, keeping-raw-source}
    @ls-path = ls-path = m.get-livescript-path pathname
    @js-path = js-path = m.get-javascript-path pathname
    @module-name = module-name = path.basename ls-path, ".ls"
    DBG "source-handler(): ls-path: %s", ls-path
    DBG "source-handler(): js-path: %s", js-path
    DBG "source-handler(): module-name: %s", module-name
    @raw-path = raw-path = path.join (path.dirname js-path), "#{path.basename js-path, '.js'}.raw.js"
    DBG "source-handler(): raw-path: %s", raw-path

  send-error: (funcname, err=null) ->
    {next, site, pathname} = self = @
    return next! unless err?
    console.error "browserify:livescript:#{funcname}(): #{site}#{pathname}, err => #{err}"
    return next err

  send-script: (filepath) ->
    {m, req, res, next} = self = @
    return m.serve-static-javascript filepath, req, res, next

  write-file: (filepath, content, done) ->
    (mkdirp-err) <- mkdirp path.dirname filepath
    return done mkdirp-err if mkdirp-err?
    (write-err) <- fs.writeFile filepath, content, {encoding: \utf8}
    return done write-err

  process: (@next) ->
    {ls-path, js-path, m, req, res, forced-compilation} = self = @
    return self.bundle! if forced-compilation
    (lerr, ls-stats) <- fs.stat ls-path
    return self.send-error \process, null if lerr? and lerr.code is ENOENT # livescript source file is missing!!
    return self.send-error \process, lerr if lerr?
    DBG "h.process(): ls-stats: %o", ls-stats
    (jerr, js-stats) <- fs.stat js-path
    return self.bundle! if jerr? and jerr.code is ENOENT
    return self.send-error \process, jerr if jerr?
    DBG "h.process(): js-stats: %o", js-stats
    return m.serve-static-javascript js-path, req, res, next unless ls-stats.mtime > js-stats.mtime
    return self.bundle!

  bundle: ->
    {req, keeping-raw-source, ls-path, raw-path} = self = @
    standalone = self.module-name
    opts = extend {}, BROWSERIFY_OPTIONS, {standalone}
    DBG "bundle(): opts => %o", opts
    bundled = ''
    b = browserify ls-path, opts
    (bundle-err, buffer) <- b.bundle
    return self.send-error \bundle, bundle-err if bundle-err?
    javascript = buffer.toString!
    DBG "bundle(): completed. total %d bytes", javascript.length
    return self.obfuscate javascript unless keeping-raw-source
    (write-err) <- self.write-file raw-path, javascript
    return self.send-error \bundle, write-err if write-err?
    DBG "bundle(): %s is written.", raw-path
    return self.obfuscate javascript

  obfuscate: (javascript) ->
    {site, pathname, js-path, m} = self = @
    url = "#{pathname}.map"
    root = site
    source-map = {url, root}
    opts = extend {}, UGLIFY_OPTIONS, {source-map}
    opts.output.preamble = "/* uglified at #{new Date!} */"
    DBG "obfuscate(): opts => %o", opts
    result = minify javascript, opts
    {error, code} = result
    return self.send-error \obfuscate, error if error?
    console.error "browserify:livescript:obfuscate(): #{site}#{pathname}, warnings =>\n#{result.warnings}" if result.warnings?
    DBG "obfuscate(): minify #{javascript.length} bytes to #{code.length} bytes"
    (write-err) <- self.write-file js-path, code
    return self.send-error \obfuscate, write-err if write-err?
    return self.send-script js-path



class Middleware
  (configs) ->
    {src, dst} = @opts = extend {}, DEFAULTS, configs
    DBG "configs: %o", configs
    DBG "opts: %o", @opts
    throw new Error "invalid src in middleware options" unless src? and (typeof src) in <[string function]>
    throw new Error "invalid dst in middleware options" unless dst? and (typeof dst) in <[string function]>
    @src = src
    @dst = dst

  get-livescript-path: (pathname) ->
    {src} = @
    return if \function is typeof src then src pathname else path.join src, pathname.replace \.js, \.ls

  get-javascript-path: (pathname) ->
    {dst} = @
    return if \function is typeof dst then dst pathname else path.join dst, pathname

  serve-static-javascript: (js-path, req, res, next) ->
    self = @
    DBG "serve-static-javascript() => js-path: %s", js-path
    (err, stat) <- fs.stat js-path
    return self.process-next-err \serve-static-javascript, err, next if err?
    mtime = (new Date stat.mtimeMs).toUTCString!
    return res.writeHead 304 .end! if mtime is req.headers['if-modified-since']
    res.statusCode = 200
    res.setHeader 'Last-Modified', mtime
    res.setHeader 'Content-Length', stat.size
    res.setHeader 'Content-Type', 'application/javascript; charset=UTF-8'
    return (fs.createReadStream js-path).pipe res

  process-source-map: (pathname, req, res, next) ->
    return next!

  process-source: (tokens, req, res, next) ->
    m = @
    h = new SourceHandler m, tokens, req, res
    return h.process next

  process-next-err: (func, err, next) ->
    DBG "#{func}(): err => %o", err
    return next err

  compile: (pathname, ls-path, js-path, full-url, req, res, next) ->
    {opts} = self = @
    (read-err, str) <- fs.read-file ls-path, {encoding: \utf8}
    return self.process-next-err \compile, read-err, next if read-err?
    DBG "compile(): livescript file size: %d bytes", str.length
    filename = pathname
    configs = extend {}, LIVESCRIPT_COMPILER_OPTIONS, {filename}
    DBG "compile(): configs => %o", configs
    try
      compiled = livescript.compile str, configs
    catch error
      return self.process-next-err \compile, error, next
    DBG "compile(): javascript file size: %d bytes", compiled.code.length
    (mkdir-err) <- mkdirp path.dirname js-path, 8~700
    return self.process-next-err \compile, mkdir-err, next if mkdir-err?
    (write-err) <- fs.write-file js-path, compiled.code, {encoding: \utf8}
    return self.process-next-err \compile, write-err, next if write-err?
    return self.serve-static-javascript js-path, req, res, next



module.exports = exports = (configs = {}) ->
  m = new Middleware configs
  f = MIDDLEWARE_CURRYING m
  return f
