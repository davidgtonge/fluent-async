
async = require "async"
fluent = require "../lib/index"

imm = (args..., cb) ->
  setImmediate ->
    cb null, Math.random() + args[0]

tim = (args..., cb) ->
  setTimeout ->
    cb null, Math.random() + args[0]
  , 0

sync = (args..., cb) ->
  cb null, Math.random() + args[0]


fn = imm

looseFluent = fluent.create()
  .add("fn1", fn, "fn0")
  .add("fn2", fn, "fn0")
  .add("fn3", fn, "fn2", "fn1")
  .add("fn4", fn, "fn2")
  .add("fn5", fn, "fn4")
  .add("fn6", fn, "fn5", "fn1")
  .add("fn7", fn, "fn6")
  .add("fn8", fn, "fn6")
  .expects("fn8", "fn7")
  .generate("fn0")

strictFluent = fluent.create()
  .strict()
  .add("fn1", fn, "fn0")
  .add("fn2", fn, "fn0")
  .add("fn3", fn, "fn2", "fn1")
  .add("fn4", fn, "fn2")
  .add("fn5", fn, "fn4")
  .add("fn6", fn, "fn5", "fn1")
  .add("fn7", fn, "fn6")
  .add("fn8", fn, "fn6")
  .expects("fn8", "fn7")
  .generate("fn0")

fluentRun = (initial, callback) ->
  fluent.create({fn0:initial})
    .add("fn1", fn, "fn0")
    .add("fn2", fn, "fn0")
    .add("fn3", fn, "fn2", "fn1")
    .add("fn4", fn, "fn2")
    .add("fn5", fn, "fn4")
    .add("fn6", fn, "fn5", "fn1")
    .add("fn7", fn, "fn6")
    .add("fn8", fn, "fn6")
    .run(callback, "fn8", "fn7")

fluentRunStrict = (initial, callback) ->
  fluent.create({fn0:initial})
  .strict()
  .add("fn1", fn, "fn0")
  .add("fn2", fn, "fn0")
  .add("fn3", fn, "fn2", "fn1")
  .add("fn4", fn, "fn2")
  .add("fn5", fn, "fn4")
  .add("fn6", fn, "fn5", "fn1")
  .add("fn7", fn, "fn6")
  .add("fn8", fn, "fn6")
  .run(callback, "fn8", "fn7")

wrap = (deps..., fn) ->
  wrapped = (cb, res) ->
    args = (res[dep] for dep in deps)
    args.push cb
    fn.apply null, args
  [].concat(deps).concat([wrapped])

initial = (data) ->
  (cb) ->
    fn(data, cb)

auto = (first, callback) ->
  async.auto
    fn1:initial(first)
    fn2:initial(first)
    fn3:wrap("fn2", "fn1", fn)
    fn4:wrap("fn2", fn)
    fn5:wrap("fn4", fn)
    fn6:wrap("fn5", "fn1", fn)
    fn7:wrap("fn6", fn)
    fn8:wrap("fn6", fn)
  , (err, res) ->
    callback(err, res.fn8, res.fn7)

wrap2 = (fn, initial) ->
  (cb) ->
    fn(initial, cb)

suite "fns", ->
  set('type', 'adaptive')
  set('mintime', 2000)

  bench "vanilla async", wrap2(auto,2)
  bench "loose fluent", wrap2(looseFluent, 2)
  bench "strict fluent", wrap2(strictFluent,2)
  bench "fluent run", wrap2(fluentRun,2)
  bench "fluent run strict", wrap2(fluentRunStrict,2)


