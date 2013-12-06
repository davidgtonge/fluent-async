module.exports = (fn, context) ->
  (args..., callback) ->
    process.nextTick ->
      try
        result = fn.apply context, args
        callback null, result
      catch e
        callback e
