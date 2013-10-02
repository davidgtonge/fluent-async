should = require "should"
fluent = require "../lib"

describe "parses options", ->
  it "throws an error if nothing added", ->
    ( -> fluent.create().add()).should.throw()

  it "throws an error if only name provided", ->
    ( -> fluent.create().add("name")).should.throw()

  it "throws an error if only function provided", ->
    ( -> fluent.create().add(->)).should.throw()

  it "throws an error if wrong arguments provided", ->
    ( -> fluent.create().add((->), "name")).should.throw()
    ( -> fluent.create().add("name", [1])).should.throw()

  it "doesn't throw an error if correct arguments provided", ->
    ( -> fluent.create().add( "name", (->))).should.not.throw()

  it "handles the optional dependancies", ->
    ( -> fluent.create().add( "name",  (->), [1,2,3])).should.not.throw()

  it "handles single object argument", ->
    ( -> fluent.create().add( "name": ->)).should.not.throw()

describe "works with data", ->
  it "correctly passes initial data as dependency", (done) ->
    test2 = (num, cb) ->
      cb.should.have.be.a.Function
      num.should.equal(123)
      cb()
    fluent.create({test:123})
      .add("test2", test2, "test")
      .run(done)

  it "correctly passes initial data as dependency when first arg is object", (done) ->
    test2 = (num, cb) ->
      cb.should.have.be.a.Function
      num.should.equal(123)
      cb()
    fluent.create({test:123})
    .add({test2}, "test")
    .run(done)

  it "correctly passes initial data as dependency when second arg is an array", (done) ->
    test2 = (num, cb) ->
      cb.should.have.be.a.Function
      num.should.equal(123)
      cb()
    fluent.create({test:123})
    .add({test2}, ["test"])
    .run(done)

  it "accepts data via data method", (done) ->
    test2 = (num, cb) ->
      cb.should.have.be.a.Function
      num.should.equal(123)
      cb()
    fluent.create()
      .data("test", 123)
      .add({test2}, "test")
      .run(done)

  it "doesn't matter the order of calling", (done) ->
    test2 = (num, cb) ->
      cb.should.have.be.a.Function
      num.should.equal(123)
      cb()
    fluent.create()
      .add({test2},"test")
      .data("test", 123)
      .run(done)

  it "works with multiple data properties", (done) ->
    test3 = (num, num2, cb) ->
      cb.should.have.be.a.Function
      num.should.equal(123)
      num2.should.equal(456)
      cb()
    fluent.create()
    .data("test", 123)
    .data("test2", 456)
    .add({test3},"test", "test2")
    .run(done)


describe "callback safety", ->
  it "ensures callbacks can only be called once", (done) ->
    test2 = (num, cb) ->
      cb.should.have.be.a.Function
      num.should.equal(123)
      ( -> cb()).should.not.throw()
      ( -> cb()).should.throw()
    fluent.create()
      .add({test2},"test")
      .data("test", 123)
      .run(done)

describe "can specify outputs", ->
  it "get single output from data", (done) ->
    fn = (err, number) ->
      number.should.equal(2)
      done(err)
    fluent.create({a:1, b:2})
      .run(fn, "b")

  it "get single output from fns", (done) ->
    b = (cb) -> cb(null, 3)

    fn = (err, number) ->
      number.should.equal(3)
      done(err)
    fluent.create()
      .add({b})
      .run(fn, "b")



# need to test outside of mocha
describe "domains", ->
  it "works", (done) ->
    f = fluent.create().domain()
    test3 = (cb) ->
      setTimeout ->
        cb(null,10)
      , 1
    test2 = (num, num2, cb) ->
      cb.should.have.be.a.Function
      num.should.equal(123)
      cb()

    f.add({test2},"test", "test3")
      .add({test3})
      .data("test", 123)
      .run(done)





