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
require! <[extend livescript mkdirp browserify exorcist through2]>
{minify} = require \uglify-es
DBG = (require \debug) \brls:middleware
sendfile = require \./sendfile

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


SEND_JS = (filepath, req, res, next) ->
  return sendfile filepath, {mime: 'application/javascript; charset=UTF-8'}, req, res, next

SEND_MAP = (filepath, req, res, next) ->
  return sendfile filepath, {mime: 'application/octet-stream'}, req, res, next

MIDDLEWARE_CURRYING = (m, req, res, next) -->
  return next! unless req.method in <[GET HEAD]>
  {pathname} = tokens = url.parse req.url
  return SEND_MAP (m.get-javascript-path pathname), req, res, next if /.js.map$/.test pathname
  return m.process-source tokens, req, res, next if /.js$/.test pathname
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
    @map-path = map-path = "#{js-path}.map"
    DBG "source-handler(): map-path: %s", map-path

  send-error: (funcname, err=null) ->
    {next, site, pathname} = self = @
    return next! unless err?
    console.error "browserify:livescript:#{funcname}(): #{site}#{pathname}, err => #{err}"
    return next err

  send-script: (filepath) ->
    {m, req, res, next} = self = @
    return SEND_JS filepath, req, res, next

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
    return SEND_JS js-path, req, res, next unless ls-stats.mtime > js-stats.mtime
    return self.bundle!

  bundle: ->
    {req, keeping-raw-source, ls-path, raw-path} = self = @
    standalone = self.module-name
    opts = extend {}, BROWSERIFY_OPTIONS, {standalone}
    DBG "bundle(): opts => %o", opts
    filepath = "#{raw-path}.map"
    (mkdirp-err) <- mkdirp path.dirname filepath
    return self.send-error \bundle, mkdirp-err if mkdirp-err?
    bundled = ''
    b = browserify ls-path, opts
    w = fs.createWriteStream raw-path
    bundled = ''
    mapped = ''
    w.on \close, ->
      DBG "bundle(): completed. total %d bytes (map %d bytes)", bundled.length, mapped.length
      (write-err) <- self.write-file filepath, mapped
      return self.send-error \bundle, write-err if write-err?
      DBG "bundle(): %s written", filepath
      return self.obfuscate bundled, mapped
    t = through2 (chunk, enc, cb) ->
      bundled := bundled + chunk
      this.push chunk
      return cb!
    n = through2 (chunk, enc, cb) ->
      mapped := mapped + chunk
      this.push chunk
      return cb!
    m = exorcist n, 'bundle.x.js'
    x = b.bundle!
    x.on \error, (bundle-err) -> return self.send-error \bundle, bundle-err if bundle-err?
    x.pipe m
      .pipe t
      .pipe w

  obfuscate: (bundled, bundle-mapped) ->
    {site, pathname, js-path, map-path, m, req} = self = @
    filename = \bundle.js
    url = "#{req.baseUrl}#{pathname}.map"
    source-map = {url}
    opts = extend {}, UGLIFY_OPTIONS, {source-map}
    opts.output.preamble = "/* minified at #{new Date!.toISOString!} */"
    DBG "obfuscate(): opts => %o", opts
    opts.source-map.content = bundle-mapped
    result = minify bundled, opts
    {error, code} = result
    return self.send-error \obfuscate, error if error?
    console.error "browserify:livescript:obfuscate(): #{site}#{pathname}, warnings =>\n#{result.warnings}" if result.warnings?
    DBG "obfuscate(): minify #{bundled.length} bytes to #{code.length} bytes, with source map #{result['map'].length} bytes"
    (write-src-err) <- self.write-file js-path, result['code']
    return self.send-error \obfuscate, write-src-err if write-src-err?
    (write-map-err) <- self.write-file map-path, result['map']
    return self.send-error \obfuscate, write-map-err if write-map-err?
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
    return SEND_JS js-path, req, res, next



module.exports = exports = (configs = {}) ->
  m = new Middleware configs
  f = MIDDLEWARE_CURRYING m
  return f
