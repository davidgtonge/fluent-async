merge = (webline, idol, callback) ->
  try
    results = _.chain([webline, idol])
    .flatten()
    .sortBy((r) -> parseFloat(r.Premium))
    .value()

    callback null, results
  catch e
    callback e


merge = (webline, idol) ->
  _.chain([webline, idol])
    .flatten()
    .sortBy((r) -> parseFloat(r.Premium))
    .value()





module.exports = (fn, context) ->
  (args..., callback) ->
    setImmediate ->
      try
        result = fn.apply context, args
        callback null, result
      catch e
        callback e
