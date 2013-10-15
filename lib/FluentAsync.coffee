async = require "async"
_ = require "underscore"
domain = require "domain"
once = require "./once"

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
    args.push(once(callback))
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
    if _.isObject(name)
      _name = _.keys(name)[0]
      if fn then depends = [fn].concat(depends)
      fn = name[_name]
      name = _name
    unless _.isString(name) and _.isFunction(fn)
      throw new Error("must provide a name and a function")
    depends = _.flatten depends
    fn = nodify @isStrict, fn, depends
    if depends.length
      deps = [].concat(depends)
      deps.push fn
      @opts[name] = deps
    else
      @opts[name] = fn
    this

  run: (callback, depends...) ->
    callback ?= ->
    handleResults = processResults(@isStrict)
    handleOpts = parseOpts(@isStrict)
    async.auto.apply async, handleOpts @opts, (err, res) ->
      handleResults callback, err, res, depends
    this

  generate: (depends...) ->
    _opts = _.clone @opts
    handleResults = processResults(@isStrict)
    handleOpts = parseOpts(@isStrict)

    (data, callback) ->
      unless callback
        callback = data
        data = {}
      opts = _.clone(_opts)
      for key, val of data
        opts[key] = functor(val)
      async.auto.apply async, handleOpts opts, (err, res) ->
        handleResults callback, err, res, depends


FluentAsync::then = FluentAsync::add
