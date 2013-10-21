module.exports = (fn, context) ->
  (args..., callback) ->
    setImmediate ->
      try
        result = fn.apply context, args
        callback null, result
      catch e
        callback e
