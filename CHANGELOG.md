# Changelog

All notable changes to this project will be documented in this file. See [standard-version](https://github.com/conventional-changelog/standard-version) for commit guidelines.

### [1.3.2](https://github.com/tic-tac-toe-io/browserify-livescript-middleware/compare/v1.3.1...v1.3.2) (2020-04-26)


### Bug Fixes

* **npm:** update node module dependencies to latest ([81d12d5](https://github.com/tic-tac-toe-io/browserify-livescript-middleware/commit/81d12d58bad3d7f066ddd857151b63e0720a7e4d))

### 1.3.1 (2020-04-26)


### Bug Fixes

* **security:** apply module update because of security advistory from github [#1](https://github.com/tic-tac-toe-io/browserify-livescript-middleware/issues/1) ([3755415](https://github.com/tic-tac-toe-io/browserify-livescript-middleware/commit/37554155817c7c54535e5b0166ef30467a12d96c))

## [1.3.0] - 2019-06-06
### Changed
- improve verbose messages
- move the logics of serving static files to `/src/sendfile.ls`
- implement livescript transform plugin for browserify in `/src/liveify.ls`

### Removed
- `browserify-livescript` is removed

### Fixed
- fix chrome browser to wait javascript when no changes, because of missing `res.end()`

## [1.2.0] - 2019-06-04
### Changed
- refactorying codes with `source-handler` class to make codes more clean
- change livescript to `ischenkodv/LiveScript` to use its 1.6.1 version with source-map 0.6.1
- extract source-map from bunelded javascript with module `exorcist`, and push this map to uglify-es

### Added
- serve source map file download
- add html entry page for `/tests/express.js` test
- add `examples/express.js`

## [1.1.3] - 2019-05-28
### Changed
- forked from https://github.com/ysulyma/livescript-middleware, and up version to `1.1.3`

### Added
- add `/package.ls` to generate `/package.json`
- add `/scripts/publish` to publish this module to npmjs registry
- add `/CHANGELOD.md` to keep change histories


## [1.1.2] - 2015-10-22
### Fixed
- Fix case of livescript package in index.ls (https://github.com/ysulyma/livescript-middleware/commit/445ea7b5e01159f443185810fb38d849084337a0)
