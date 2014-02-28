debug = require("debug")("fluent")
_ = require "underscore"

module.exports = (fn, delay, name = "Fluent Async Function", log) ->
  called = false
  timedOut = false
  if delay
    timer = setTimeout ->
      timedOut = true
      debug "#{name} didn't finish within #{delay}ms"
      fn(new Error("#{name} didn't finish within #{delay}ms"))
    , delay
  (err) ->
    clearTimeout(timer)
    if timedOut
      # stop doing anything if the function came back too late
      return
    else if called
      # function didn't time out, but was called more than once - probably an error in the application code
      debug "callback called more than once from #{name}"
      return throw new Error "callback called more than once from #{name}"
    called = true
    debug "Callback for #{name}"
    if err
      if err.message? and _.isString(err.message)
        err.message = "at method #{name} in fluent chain: #{err.message}"
      else if _.isString(err)
        err = "Error: at method #{name} in fluent chain: #{err}"
      fn(err)
    else
      fn.apply this, arguments
