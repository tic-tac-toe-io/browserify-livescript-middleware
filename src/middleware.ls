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
require! <[extend livescript mkdirp]>
{minify} = require \uglify-es
DBG = (require \debug) \browserify-livescript-middleware


const DEFAULTS =
  src: null
  dst: null
  livescript:
    bare: yes
    map: \embedded


MIDDLEWARE_CURRYING = (m, req, res, next) -->
  return m.process req, res, next


class Middleware
  (configs) ->
    {src, dst} = @opts = extend {}, DEFAULTS, configs
    DBG "configs: %o", configs
    DBG "opts: %o", @opts
    throw new Error "invalid src in middleware options" unless src? and (typeof src) in <[string function]>
    throw new Error "invalid dst in middleware options" unless dst? and (typeof dst) in <[string function]>

  process-source-map: (pathname, res, next) ->
    return next!

  serve-static-javascript: (js-path, res, next) ->
    DBG "serve-static-javascript() => js-path: %s", js-path
    return next!

  process: (req, res, next) ->
    process-err = (err) -> return next if err.code is \ENOENT then null else err
    {opts} = self = @
    {src, dst} = opts
    return next! unless req.method in <[GET HEAD]>
    {protocol, originalUrl} = req
    {pathname} = tokens = url.parse req.url
    is-js = /.js$/.test pathname
    is-map = /.js.map$/.test pathname
    return next! unless is-js or is-map
    return self.process-source-map pathname, res, next if is-map
    hostname = req.get \host
    full-url = "#{protocol}://#{hostname}#{originalUrl}"
    DBG "process(): req.originalUrl => %s", originalUrl
    DBG "process(): req.path => %s", req.path
    DBG "process(): req.url => %s", req.url
    DBG "process(): hostname => %s", hostname
    DBG "process(): full-url => %s", full-url
    DBG "process(): pathname => %s", pathname
    js-path = if \function is typeof dst then dst pathname else path.join dst, pathname
    ls-path = if \function is typeof src then src pathname else path.join src, pathname.replace \.js, \.ls
    DBG "process(): js-path: %s", js-path
    DBG "process(): ls-path: %s", ls-path
    fs.stat ls-path, (err, ls-stats) ->
      DBG "process(): looking for livescript file stats => %o", err
      return process-err err if err?
      fs.stat js-path, (err, js-stats) ->
        return self.compile pathname, ls-path, js-path, full-url, req, res, next if err? and err.code is \ENOENT
        return process-err err if err?
        return self.compile pathname, ls-path, js-path, full-url, req, res, next if ls-stats.mtime > js-stats.mtime
        return self.serve-static-javascript js-path, res, next

  process-next-err: (func, err, next) ->
    DBG "#{func}(): err => %o", err
    return next err

  compile: (filename, ls-path, js-path, full-url, req, res, next) ->
    {opts} = self = @
    DBG "compile(): ls-path => %s", ls-path
    (read-err, str) <- fs.read-file ls-path, {encoding: \utf8}
    return self.process-next-err \compile, read-err, next if read-err?
    DBG "compile(): livescript file size: %d bytes", str.length
    configs = extend {}, opts.livescript, {filename}
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
    return self.serve-static-javascript js-path, res, next



/**
 * Module dependencies.
 */

module.exports = exports = (configs = {}) ->
  m = new Middleware configs
  f = MIDDLEWARE_CURRYING m
  return f