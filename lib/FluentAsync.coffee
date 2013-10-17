async = require "async"
_ = require "underscore"
domain = require "domain"
once = require "./once"
makeAsync = require "./makeAsync"

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

nodifyStrict = (fn, depends) ->
  (callback, results) =>
    args = []
    for depend in depends
      val = results[depend]
      if val?
        args.push(val)
      else
        return callback(new Error "Fluent: Strict Mode - Missing result from #{depend}")
    args.push(once(callback))
    fn.apply this, args

nodify = (strict, fn, depends) ->
  if strict
    nodifyStrict(fn, depends)
  else
    nodifyLoose(fn, depends)

parseOptsStrict = (opts, cb) ->
  diff = _.chain(opts)
    .filter(_.isArray)
    .flatten()
    .filter(_.isString)
    .unique()
    .difference(_.keys(opts))
    .value()
  if diff.length
    cb(new Error("Fluent:Strict - Missing dependencies: #{diff.join(",")}"))
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
    for key, val of initial
      @data key, val

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
    fn = nodify @isStrict, fn, depends
    if depends.length
      deps = [].concat(depends)
      deps.push fn
      @opts[name] = deps
    else
      @opts[name] = fn
    this

  addSync: (name, fn, depends...) ->
    args = normalizeAddArgs(name, fn, depends)
    args[1] = makeAsync(args[1])
    @_add.apply @, args

  run: (callback, depends...) ->
    callback ?= ->
    handleResults = processResults(@isStrict)
    handleOpts = parseOpts(@isStrict)
    async.auto.apply async, handleOpts @opts, (err, res) ->
      handleResults callback, err, res, depends
    this

  output: (args...) ->
    @finalArgs = args
    this

  generate: (expected...) ->
    _opts = _.clone @opts
    isStrict = @isStrict
    handleResults = processResults(isStrict)
    handleOpts = parseOpts(isStrict)
    depends = _.clone(@finalArgs) ? []

    (data..., callback) ->
      opts = _.clone(_opts)
      if isStrict and (expected.length isnt data.length)
        return callback(new Error("Incorrect number of arguments supplied"))
      for val, index in data
        opts[expected[index]] = functor(val)
      async.auto.apply async, handleOpts opts, (err, res) ->
        handleResults callback, err, res, depends


FluentAsync::results = FluentAsync::output
FluentAsync::sync = FluentAsync::addSync
FluentAsync::then = FluentAsync::async = FluentAsync::add

