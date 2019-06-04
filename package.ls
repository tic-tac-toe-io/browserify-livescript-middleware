#!/usr/bin/env lsc -cj
#
# Known issue:
#   when executing the `package.ls` directly, there is always error
#   "/usr/bin/env: lsc -cj: No such file or directory", that is because `env`
#   doesn't allow space.
#
#   More details are discussed on StackOverflow:
#     http://stackoverflow.com/questions/3306518/cannot-pass-an-argument-to-python-with-usr-bin-env-python
#
#   The alternative solution is to add `envns` script to /usr/bin directory
#   to solve the _no space_ issue.
#
#   Or, you can simply type `lsc -cj package.ls` to generate `package.json`
#   quickly.
#

# package.json
#
name: \@tic-tac-toe/browserify-livescript-middleware

version: \x.x.x

main: \index.js

description: "Connect middleware for LiveScript with Browserify support"

keywords: <[livescript middleware connect browserify uglify-es]>

author: "yagamy <yagamy@gmail.com> (https://github.com/yagamy4680)"

bugs:
  url: \https://github.com/tic-tac-toe-io/browserify-livescript-middleware/issues

license: \MIT

repository:
  type: \git
  url: \git://github.com/tic-tac-toe-io/browserify-livescript-middleware.git

dependencies:
  mkdirp: \^0.5.1
  extend: \^3.0.2
  livescript: \github:ischenkodv/LiveScript
  \source-map : \=0.6.1
  \source-map-support : \=0.5.11
  browserify : \^16.2.2
  \browserify-livescript : \^0.2.3
  \exorcist : \*
  \uglify-es : \^3.3.9
  \fast-json-patch : \^2.0.6
  \debug : \*


devDependencies:
  express: \*

optionalDependencies: {}

files: <[
  /src/**/*
  /examples/**/*
  ]>

homepage: \https://github.com/tic-tac-toe-io/browserify-livescript-middleware#readme

directories:
  doc: \docs
  example: \examples
  test: \tests