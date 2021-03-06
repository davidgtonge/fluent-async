async = require "async"
_ = require "underscore"
once = require "./once"
makeAsync = require "./makeAsync"
debug = require("debug")("fluent")

functor = (val) ->
  (cb) -> cb(null, val)

firstArg = (item) -> item.split(".")[0]

getDependResult = (result, key) ->
  if key.indexOf(".") isnt -1
    keys = key.split(".")
    for key in keys
      if result then result = result[key]
    result
  else
    result[key]

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
      val = getDependResult(res,depend)
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

nodifyStrict = (fn, depends, delay, name, logger, showErrorPath) ->
  (callback, results) =>
    args = []
    for depend in depends
      val = getDependResult(results,depend)
      if val?
        args.push(val)
      else
        logger "Strict Mode - Missing result from #{depend}"
        return callback(new Error "Fluent: Strict Mode - Missing result from #{depend}")

    args.push(once(callback, delay, name, logger, showErrorPath))
    len = fn._length ? fn.length
    if args.length isnt len
      logger("Inconsistent Arity: #{name} - #{args.length} supplied, #{len} expected")
    logger "Running #{name}"
    try
      fn.apply this, args
    catch e
      callback(e)

nodify = (strict, fn, depends, delay, name, logger, showErrorPath) ->
  if strict
    nodifyStrict(fn, depends, delay, name, logger, showErrorPath)
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
    throw new Error("Fluent: Missing name: #{name} or function: #{fn?.toString()}")
  depends = _.flatten depends
  [name, fn, depends]

createWrapper = (type) ->
  (tempIfFn, tempIfDepends, logger) ->
    if _.isBoolean(tempIfFn)
      ifFn = -> tempIfFn
    else if _.isFunction(tempIfFn)
      ifFn = tempIfFn
    else
      ifFn = _.values(tempIfFn)[0]

    wrapper = (name, fn, depends) ->
      ifDepends = []
      duplicateDeps = []
      for dep, index in tempIfDepends
        if dep in depends
          argIndex = _.indexOf(depends, dep)
          duplicateDeps.push {index, argIndex}
        else
          ifDepends.push(dep)

      depends = ifDepends.concat(depends)

      wrappedFn = (args...) ->
        ifArgs = args.slice 0, ifDepends.length
        originalArgs = args.slice ifDepends.length
        for {argIndex, index} in duplicateDeps
          ifArgs.splice(index, 0, originalArgs[argIndex])

        ifResult = ifFn.apply this, ifArgs
        if (type is "if" and ifResult) or (type is "else" and not ifResult)
          fn.apply this, originalArgs
        else
          logger("Skipping #{name} due to #{type}")
          _.last(originalArgs).call this, null, false
      wrappedFn._length = (fn._length ? fn.length) + ifDepends.length
      [name, wrappedFn, depends]
    if type is "if" then elseWrapper = createWrapper("else")(ifFn, tempIfDepends, logger)
    {wrapper, type, elseWrapper}

createIfWrapper = createWrapper("if")


module.exports = class FluentAsync

  constructor: (initial = {}, showErrorPath) ->
    @opts = {}
    @waiting = []
    @_conditionals = []
    @_log = debug
    @showErrorPath = showErrorPath
    for key, val of initial
      @data key, val

  name: (@_name) ->
    @_log = require("debug")("fluent:#{@_name}")
    this

  "if": (fn, depends...) ->
    @_conditionals.push createIfWrapper(fn, depends, @_log)
    this


  "else": ->
    if @_conditionals.length
      if _.last(@_conditionals).type is "else"
        throw new Error "Can't call else after another else - be sure to call endif"
      else
        {elseWrapper} = @_conditionals.pop()
        @_conditionals.push elseWrapper

    else
     throw new Error "Can't call else without a preceeding if"
    this

  endif: ->
    if @_conditionals.length
      @_conditionals.pop()
    # clear last fn from stack
    else
      throw new Error "Can't call endif without a preceeding if"
    this


  strict: ->
    @isStrict = true
    this

  push: (key, val) ->
    if @opts[key]
      throw new Error ("Fluent: Either data or a function with this name has already been added")
    else
      @opts[key] = val
      this

  data: (key, val) ->
    @push key, functor(val)
    this

  add: (name, fn, depends...) ->
    @_add.apply @, normalizeAddArgs(name, fn, depends)

  _add: (name, fn, depends) ->
    for {wrapper} in @_conditionals
      [name, fn, depends] = wrapper(name, fn, depends)
    fn = nodify @isStrict, fn, depends, @delay, name, @_log, @showErrorPath
    depends = _.map depends, firstArg
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
    if @_conditionals.length then callback new Error("If statements not closed")
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


FluentAsync::results = FluentAsync::expects = FluentAsync::output
FluentAsync::sync = FluentAsync::addSync
FluentAsync::then = FluentAsync::async = FluentAsync::add
