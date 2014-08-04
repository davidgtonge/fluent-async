# Should create the correct data structures for Async auto
# should be fluent
# optionally use errors for flow control
_ = require "underscore"
FluentAsync = require "./FluentAsync"
FluentAsyncWithMocks = require "./FluentAsyncWithMocks"

create = (data) ->
  new FluentAsync data

createWithMocks = (mocks) ->
  (data) ->
    instance = new FluentAsyncWithMocks data
    instance._mocks = mocks
    instance

output =
  FluentAsync: FluentAsync
  makeAsync: require "./makeAsync"
  create: create
  enableMocks: (mocks = {}) ->
    output.create = createWithMocks(mocks)
  firstValid: (args...) -> _.detect(args, _.identity)


module.exports = output

