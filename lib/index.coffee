# Should create the correct data structures for Async auto
# should be fluent
# optionally use errors for flow control

FluentAsync = require "./FluentAsync"
makeAsync = require "./makeAsync"

create = (data) ->
  new FluentAsync data

module.exports = {FluentAsync, create, makeAsync}