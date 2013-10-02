module.exports = (fn) ->
  called = false
  ->
    if called then return throw new Error "callback called more than once"
    called = true
    fn.apply this, arguments