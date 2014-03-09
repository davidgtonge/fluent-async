async = require "async"
_ = require "underscore"
domain = require "domain"
once = require "./once"
makeAsync = require "./makeAsync"
debug = require("debug")("fluent")

functor = (val) ->
  (cb) -> cb(null, val)

processResultsLoose = (cb, err, res, depends) ->
  if depends.length
    args = (res[depend] for depend in depends)
    args.unshift(err)
    cb.apply this, args
  else
    cb err, res

processResultsStrict = (cb, err, res, depends) ->
  return cb(err) if err
  if depends.length
    args = [err]
    for depend in depends
      val = res[depend]
      if val?
        args.push val
      else
        debug "Strict Mode - Missing result from #{depend}"
        return cb(new Error "Fluent: Strict Mode - Missing result from #{depend}")
    cb.apply this, args
  else
    cb err, res

processResults = (strict) ->
  if strict then processResultsStrict else processResultsLoose

nodifyLoose = (fn, depends) ->
  (callback, results) =>
    args = (results[depend] for depend in depends)
    args.push(callback)
    fn.apply this, args

nodifyStrict = (fn, depends, delay, name, logger) ->
  (callback, results) =>
    args = []
    for depend in depends
      val = results[depend]
      if val?
        args.push(val)
      else
        logger "Strict Mode - Missing result from #{depend}"
        return callback(new Error "Fluent: Strict Mode - Missing result from #{depend}")

    args.push(once(callback, delay, name, logger))
    len = fn._length ? fn.length
    if args.length isnt len
      logger("Inconsistent Arity: #{name} - #{args.length} supplied, #{len} expected")
    logger "Running #{name}"
    try
      fn.apply this, args
    catch e
      callback(e)

nodify = (strict, fn, depends, delay, name, logger) ->
  if strict
    nodifyStrict(fn, depends, delay, name, logger)
  else
    nodifyLoose(fn, depends)

parseOptsStrict = (opts, cb, logger) ->
  diff = _.chain(opts)
    .filter(_.isArray)
    .flatten()
    .filter(_.isString)
    .unique()
    .difference(_.keys(opts))
    .value()
  if diff.length
    errMsg = "Strict Mode - Missing dependencies: #{diff.join(",")}"
    logger(errMsg)
    cb(new Error errMsg)
    [{}, ->]
  else
    [opts, cb]

parseOptsLoose = (opts, cb) -> [opts, cb]

parseOpts = (strict) ->
  if strict then parseOptsStrict else parseOptsLoose

normalizeAddArgs = (name, fn, depends) ->
  if _.isObject(name)
    _name = _.keys(name)[0]
    if fn then depends = [fn].concat(depends)
    fn = name[_name]
    name = _name
  unless _.isString(name) and _.isFunction(fn)
    throw new Error("must provide a name and a function")
  depends = _.flatten depends
  [name, fn, depends]


module.exports = class FluentAsync

  constructor: (initial = {}) ->
    @opts = {}
    @waiting = []
    @_log = debug
    for key, val of initial
      @data key, val

  name: (@_name) ->
    @_log = require("debug")("fluent:#{@_name}")
    this

  strict: ->
    @isStrict = true
    this

  push: (key, val) ->
    if @opts[key]
      throw new Error ("either data or a function with this name has already been added")
    else
      @opts[key] = val
      this

  data: (key, val) ->
    @push key, functor(val)
    this

  add: (name, fn, depends...) ->
    @_add.apply @, normalizeAddArgs(name, fn, depends)

  _add: (name, fn, depends) ->
    fn = nodify @isStrict, fn, depends, @delay, name, @_log
    if depends.length or @waiting.length
      deps = _.union depends, @waiting
      deps.push fn
      @opts[name] = deps
    else
      @opts[name] = fn
    @_lastAdded = name
    this

  log: ->
    lastName = @_lastAdded
    fn = (callback, results) =>
      try
        @_log "Result for #{lastName}: #{JSON.stringify(results[lastName])}"
        callback()
      catch e
        callback(e)
    @opts["fluent.log.#{lastName}"] = [lastName, fn]
    this

  maxTime: (@delay) ->
    throw new Error("Fluent Async: Must be in strict mode to have maxTime") unless @isStrict
    this

  wait: (depends...) ->
    # needs to rather add dependencies to any future additions
    depends = _.keys(@opts) unless depends.length
    @waiting = @waiting.concat(depends)
    this

  addSync: (name, fn, depends...) ->
    args = normalizeAddArgs(name, fn, depends)
    args[1] = makeAsync(args[1])
    @_add.apply @, args

  run: (callback, depends...) ->
    callback ?= ->
    handleResults = processResults(@isStrict)
    handleOpts = parseOpts(@isStrict)
    finalCallback = (err, res) -> handleResults(callback, err, res, depends)
    async.auto.apply async, handleOpts(@opts, finalCallback, @_log)
    this

  output: (args...) ->
    @finalArgs = args
    this

  generate: (expected...) ->
    _opts = _.clone @opts
    isStrict = @isStrict
    log = @_log
    handleResults = processResults(isStrict)
    handleOpts = parseOpts(isStrict)
    depends = _.clone(@finalArgs) ? []

    (data..., callback) ->
      opts = _.clone(_opts)
      if isStrict and (expected.length isnt data.length)
        log "Incorrect number of arguments supplied"
        return callback(new Error("Incorrect number of arguments supplied"))
      for val, index in data
        opts[expected[index]] = functor(val)
      async.auto.apply async, handleOpts opts, (err, res) ->
        handleResults callback, err, res, depends


FluentAsync::results = FluentAsync::output
FluentAsync::sync = FluentAsync::addSync
FluentAsync::then = FluentAsync::async = FluentAsync::add

