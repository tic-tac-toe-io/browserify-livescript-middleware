#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#

require! <[fs path]>
DBG = (require \debug) \brls:sendfile


send_error = (func, next, err) ->
  DBG "#{func}(): err => %o", err
  return next err


send_304 = (filepath, res) ->
  res.writeHead 304
  res.end!
  return DBG "send_304() => filepath: %s", filepath


handle_req = (filepath, opts, req, res, next) ->
  DBG "handle_req() => url: %s, filepath: %s", req.originalUrl, filepath
  (err, stat) <- fs.stat filepath
  return send_error \handle_req, next, err if err?
  DBG "handle_req() => stat: %o", stat
  mtime = (new Date stat.mtimeMs).toUTCString!
  return send_304 filepath, res if mtime is req.headers['if-modified-since']
  {mime} = opts
  res.statusCode = 200
  res.setHeader 'Last-Modified', mtime
  res.setHeader 'Content-Length', stat.size
  res.setHeader 'Content-Type', mime if mime? and \string is typeof mime
  DBG "handle_req() => mime: %s", mime if mime?
  return (fs.createReadStream filepath).pipe res


module.exports = exports = handle_req