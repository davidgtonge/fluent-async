_ = require "underscore"

module.exports = (fn, delay, name = "Fluent Async Function", logger, showErrorPath) ->
  called = false
  timedOut = false
  if delay
    timer = setTimeout ->
      timedOut = true
      logger "#{name} didn't finish within #{delay}ms"
      fn(new Error("#{name} didn't finish within #{delay}ms"))
    , delay
  (err) ->
    clearTimeout(timer)
    if timedOut
      # stop doing anything if the function came back too late
      return
    else if called
      # function didn't time out, but was called more than once - probably an error in the application code
      logger "callback called more than once from #{name}"
      return throw new Error "callback called more than once from #{name}"
    called = true
    logger "Callback for #{name}"
    if err
      if err.message? and _.isString(err.message)
        logMessage = "at method #{name} in fluent chain: #{err.message}"
      else if _.isString(err)
        logMessage = "Error: at method #{name} in fluent chain: #{err}"
      else
        logMessage = err

      if showErrorPath
        if err.message?
          err.message = logMessage
        else
          err = logMessage

      logger(logMessage.toString())
      fn(err)
    else
      fn.apply this, arguments
