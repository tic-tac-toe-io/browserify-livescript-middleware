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


const DEFAULTS =
  src: null
  dst: null

const LIVESCRIPT_COMPILER_OPTIONS =
  bare: yes
  map: \embedded


MIDDLEWARE_CURRYING = (m, req, res, next) -->
  return next! unless req.method in <[GET HEAD]>
  {pathname} = tokens = url.parse req.url
  return m.process-source pathname, req, res, next if /.js$/.test pathname
  return m.process-source-map pathname, req, res, next if /.js.map$/.test pathname
  return next!


class Middleware
  (configs) ->
    {src, dst} = @opts = extend {}, DEFAULTS, configs
    DBG "configs: %o", configs
    DBG "opts: %o", @opts
    throw new Error "invalid src in middleware options" unless src? and (typeof src) in <[string function]>
    throw new Error "invalid dst in middleware options" unless dst? and (typeof dst) in <[string function]>

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

  process-source: (pathname, req, res, next) ->
    ##
    # Inspired by https://github.com/ysulyma/livescript-middleware/blob/master/index.ls
    #
    process-err = (err) -> return next if err.code is \ENOENT then null else err
    {opts} = self = @
    {src, dst} = opts
    {protocol, originalUrl, query} = req
    {forced} = query
    hostname = req.get \host
    full-url = "#{protocol}://#{hostname}#{originalUrl}"
    DBG "process(): req => originalUrl: %s, path: %s, url: %s", originalUrl, req.path, req.url
    DBG "process(): hostname => %s, pathname => %s", hostname, pathname
    DBG "process(): full-url => %s", full-url
    js-path = if \function is typeof dst then dst pathname else path.join dst, pathname
    ls-path = if \function is typeof src then src pathname else path.join src, pathname.replace \.js, \.ls
    DBG "process(): ls-path => %s", ls-path
    DBG "process(): js-path => %s", js-path
    (lerr, ls-stats) <- fs.stat ls-path
    DBG "process(): looking for livescript file stats, err: %s", lerr
    return process-err lerr if lerr?
    return self.bundle pathname, ls-path, js-path, full-url, req, res, next if forced is \true
    (jerr, js-stats) <- fs.stat js-path
    DBG "process(): looking for javascript file stats, err: %o", jerr
    return self.bundle pathname, ls-path, js-path, full-url, req, res, next if jerr? and jerr.code is \ENOENT
    # return self.compile pathname, ls-path, js-path, full-url, req, res, next if jerr? and jerr.code is \ENOENT
    return process-err jerr if jerr?
    return self.serve-static-javascript js-path, req, res, next unless ls-stats.mtime > js-stats.mtime
    return self.bundle pathname, ls-path, js-path, full-url, req, res, next
    # return self.compile pathname, ls-path, js-path, full-url, req, res, next

  process-next-err: (func, err, next) ->
    DBG "#{func}(): err => %o", err
    return next err

  obfuscate: (javascript, pathname, ls-path, js-path, full-url, req, res, next) ->
    self = @
    filename = pathname
    url = "#{filename}.map"
    {protocol, baseUrl, query} = req
    hostname = req.get \host
    root = "#{protocol}://#{hostname}#{baseUrl}"
    configs =
      compress: {passes: 2}
      mangle: true
      output: {beautify: false, preamble: "/* uglified */"}
      source-map: {url, root}
    DBG "obfuscate(): configs => %o", configs
    result = minify javascript, configs
    {error} = result
    return next error if error?
    DBG "obfuscate(): warnings\n#{result.warnings}" if result.warnings?
    DBG "obfuscate(): minify #{javascript.length} bytes to #{result.code.length} bytes"
    (err1) <- fs.write-file js-path, result.code, {encoding: \utf8}
    return self.process-next-err \obfuscate, err1, next if err1?
    js-map-path = "#{js-path}.map"
    DBG "obfuscate(): source-map #{result.map.length} bytes, writing to #{js-map-path}"
    (err2) <- fs.write-file js-map-path, result.map, {encoding: \utf8}
    return self.process-next-err \obfuscate, err2, next if err2?
    return self.serve-static-javascript js-path, req, res, next

  bundle: (pathname, ls-path, js-path, full-url, req, res, next) ->
    {query} = req
    {raw} = query
    self = @
    configs =
      debug: yes # for source-map support
      transform: <[browserify-livescript]>
      extensions: <[.ls]>
      standalone: path.basename ls-path, ".ls"
    DBG "bundle(): configs => %o", configs
    js-raw-path = path.join (path.dirname js-path), "#{path.basename js-path, '.js'}.raw.js"
    DBG "bundle(): js-raw-path => %s", js-raw-path
    bundled = ''
    b = browserify ls-path, configs
    w = fs.createWriteStream js-raw-path
    w.on \close, ->
      DBG "bundle(): completed, total %d bytes", bundled.length
      return self.obfuscate bundled, pathname, ls-path, js-path, full-url, req, res, next
    t = through2 (chunk, enc, cb) ->
      bundled := bundled + chunk
      this.push chunk
      return cb!
    b.bundle! .pipe t .pipe w

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
