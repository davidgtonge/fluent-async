debug = require("debug")("fluent")

module.exports = (fn, delay, name = "Fluent Async Function", log) ->
  called = false
  timedOut = false
  if delay
    timer = setTimeout ->
      timedOut = true
      debug "#{name} didn't finish within #{delay}ms"
      fn(new Error("#{name} didn't finish within #{delay}ms"))
    , delay
  ->
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
    fn.apply this, arguments
