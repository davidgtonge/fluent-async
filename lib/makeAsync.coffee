module.exports = (fn, context) ->
  asyncFn = (args..., callback) ->
    process.nextTick ->
      try
        result = fn.apply context, args
        callback null, result
      catch e
        callback e
  # so we can check function arity against dependancies
  asyncFn._length = fn.length + 1
  asyncFn