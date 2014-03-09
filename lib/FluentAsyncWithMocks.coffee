FluentAsync = require "./FluentAsync"
_ = require "underscore"

mocker = (args, logger, name) ->
  (callback) ->
    logger("Mocking: #{name}")
    callback.apply this, args


module.exports = class FluentAsyncWithMocks extends FluentAsync

  run: ->
    mocks = @_mocks[@_name]
    if mocks
      for key, vals of @opts when mocks[key]
        fn = mocker(mocks[key], @_log, key)
        if _.isArray(vals)
          vals.pop()
          vals.push(fn)
        else
          @opts[key] = fn
    super