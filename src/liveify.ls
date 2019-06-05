#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#
require! <[fs path]>
require! <[livescript through2 extend]>
convert = require \convert-source-map
DBG = (require \debug) \brls:liveify


const DEFAULTS =
  bare: yes
  header: no
  map: 'embedded'


compile = (filename, src, opts, cb) ->
  DBG "compile(): filename => %s", filename
  try
    compiled = livescript.compile src, opts
  catch error
    DBG "compile(): err => %o", error
    return cb error
  xs = [ k for k, v of compiled ]
  DBG "compile(): xs => %o", xs
  DBG "compile(): map\n%s", compiled.map
  DBG "compile(): code\n%s", compiled.code
  return cb null, compiled.code


is-live = (file) ->
  return /.*\.ls$/.test file


liveify-currying = (dir, filename, options) -->
  return through2! unless is-live filename
  DBG "liveify(): dir: %s", dir
  DBG "liveify(): filename: %s", filename
  name = filename
  name = "/__src__#{filename.substring dir.length}" if filename.startsWith dir
  opts = extend {}, DEFAULTS, options, {filename: name}
  DBG "liveify(): opts => %o", opts
  chunks = []
  transform = (chunk, encoding, cb) ->
    chunks.push chunk
    return cb!
  flush = (cb) ->
    stream = @
    source = (Buffer.concat chunks).toString!
    DBG "liveify(): read %d bytes from livescript source", source.length
    (err, result) <- compile filename, source, opts
    return cb err if err?
    DBG "liveify(): compiled javascript => %d bytes", result.length
    stream.push result
    return cb!
  return through2 transform, flush


module.exports = exports = (dir) ->
  transform = liveify-currying dir
  return transform
