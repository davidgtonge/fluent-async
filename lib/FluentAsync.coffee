async = require "async"
_ = require "underscore"
domain = require "domain"
once = require "./once"

functor = (val) ->
  (cb) -> cb(null, val)


module.exports = class FluentAsync

  constructor: (initial = {}) ->
    @opts = {}
    for key, val of initial
      @data key, val

  domain: ->
    @d = domain.create()
    @d.on "error", (e) ->
      throw e

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

  process: (cb) ->
    if @d
      @d.bind(cb)
    else
      cb

  nodify: (fn, depends) ->
    (callback, results) =>
      args = (results[depend] for depend in depends)
      args.push(@process once(callback))
      fn.apply this, args

  add: (name, fn, depends...) ->
    if _.isObject(name)
      _name = _.keys(name)[0]
      if fn then depends = [fn].concat(depends)
      fn = name[_name]
      name = _name
    unless _.isString(name) and _.isFunction(fn)
      throw new Error("must provide a name and a function")
    depends = _.flatten depends
    fn = @nodify fn, depends
    if depends.length
      deps = [].concat(depends)
      deps.push fn
      @opts[name] = deps
    else
      @opts[name] = fn

    this

  processResults: (cb, err, res, depends) ->
    if depends.length
      args = (res[depend] for depend in depends)
      args.unshift(err)
      cb.apply this, args
    else
      cb err, res


  run: (callback, depends...) ->
    callback ?= ->
    if @d
      @d.run =>
        async.auto @opts, (err, res) =>
          @d.dispose()
          @processResults callback, err, res, depends
    else
      async.auto @opts, (err, res) =>
        @processResults callback, err, res, depends

    this
