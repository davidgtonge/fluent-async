fluent-async
============

## Fluent interface to [Async Auto from Caolan](https://github.com/caolan/async#auto)

I love Async.auto. Its a great utility that allows you to express your asynchronous dependencies as
a simple data structure. The library works out which calls can be made in paralell, which in series,
which calls depend on other calls, as well as halting on any errors.

I heve a few issues with the API however:

 - Functions need to be supplied in a non node-standard way, e.g. ` function(callback, data) {}`
 I'd much rather have `function(data, callback){}`
 - It's jQuery Ajax configuration by object style, rather than jQuery fluent dom manipulation style
 - Configuration by object is ugly and arguably harder to adjust later on
 - I feel like I'm writing too much boiler plate with many of my Async.auto calls

I'm a big fan of fluent interfaces, so I wrote this simple wrapper.
Here's an example

```js
fluent = require("fluent-async")
fluent.create({id:1})  // Initial data can be passed in as an object
  .data("projection", {profile:1}) // Further data can be added via the data method
  .async("getUser", getUser, "id", "projection") // getUser will be called with id, projection, callback
  .async("getFriends", getFriends, "getUser") // getFriends will be called with result of getUser and a callback
  .async("getMessages", getMessages, "getUser") // will be run parallel to above
  .run(render, "getMessages", "getFriends") // render function will be called with err, messages, friends

```

Here's another example in coffee-script (taking advantage of easy object creation)

```coffeescript
fluent = require("fluent-async")
fluent.create({id:1})
    .data("projection", {profile:1})
    .async({getUser}, ["id","projection"]) # dependencies can also be supplied as an array
    .async({getFriends}, "getUser")
    .async({getMessages}, "getUser")
    .run(render, "getMessages", "getFriends")

```


### Ensuring callbacks are only called once

Some of the harder to find bugs that I've encountered using node is when you trigger a callback more than once
This is normally due to an error in your code path, but it often ends up having weird side effects and might
not always be noticed.

To help avoid these bugs, you can enable strict mode and this library will throw an error if you attempt to
call one of the supplied callbacks more than once.

### Tests

There is a set of Mocha unit tests. Run `npm test` to see the results

### API

#### `.create(data)`

This method creates a new Fluent-Async instance. You can optionally pass in data to the method.
Any data supplied will be added to the instance and will be available as dependencies.


#### `.data(key, val)`

This is another way of adding static data to the instance.

#### `.async(name, fn, dependencies...)` or `.async({name:fn}, dependencies...)` - alised to `add()`

This method is where you can add your async functions and their dependencies.
Dependencies can be supplied as either an array or a list of arguments. Dependencies are optional.
If no dependencies are supplied that the function will be called with one argument: the callback:
`fn(callback)`

If 1 dependency is supplied the function will be called with 2 arguments:
`.add("fn", fn, "dep1")` will result in `fn` being called like this `fn(dep1Result, callback)`

And so on, e.g. with 2 dependencies:
`.add("fn", fn, "dep1", "dep2")` will result in `fn` being called like this
`fn(dep1Result, dep2Result, callback)`

`.add("fn", fn, "dep1", "dep2")` is the same as `.add("fn", fn, ["dep1", "dep2"])` is the same as
`.add({"fn":fn}, "dep1", "dep2")`

#### `.sync(name, fn, dependencies...)`

This method works the same as adding async functions, except that the function supplied must be synchronous.
For example:

```coffeescript
syncFn = (a) -> a * 10
fluent.create({b:10}).sync({a}, "b").generate("a")
````
Internally the function is run within a try / catch block, this ensures that any errors are caught and passed up the callback chain.
The function is also run using `setImmediate` ensuring that the event loop is not blocked by running many synchonous functions.


#### `.strict()`

This will enable *strict* mode for the instance. This means that:

 - If there is an unmet dependency an error will be passed to the final callback and no processing will take place
 - If one of the async functions returned a null or undefined value and that value is depended on by another function,
 then an error will be created
  - If one of the async functions returned a null or undefined value and that value is depended on by the final callback
  then an error will be created

I would recommend running the library with `strict` enabled as it should help you reason better about your async calls.
If its reasonable for some of your async calls to return null or undefined then leave strict mode off.

#### `.run(callback, deps...)`

This method starts running the async calls straight away. The callback supplied to this method will be called
when all the methods added are complete, or if there is any error.
If you supply dependencies to this method, then the callback will be called with the results of the defined
dependencies.

#### `.expects(args...)` or `.output(args...)`

This method works with the `generate` method. It allows you to define which of the results you want to be passed
to your final callback.

#### `.generate(expected...)`

This method produces a function that can be called repeatedly - no data is leaked between runs. This means that you
can define your async function path on startup and use it again and again without constantly redefining it.

You can also specify the names of any of the arguemnts that will be supplied to the generated function. This allows
functions produced by this method to work well with other node code, without the need for wrapping functions.

The signature of the method produced by this function is `function(data..., callback){}`.
In strict mode the number of data arguments must be equal to the number of expected arguments.
If no expected arguments are supplied, then the resulting function can be called with just a single callback as its
argument.

#### `.wait()` or `.wait(depends...)`

This method ensures that any further methods wait for all the previous methods to be completed.
This can be useful if a method doesn't depend on the data from another method, but should only be completed
if that method has been completed. Optionally dependencies can be supplied to this method. If none are supplied
then we assume that all previous operations are dependencies.

Here is an example with some mongodb queries:

```coffeescript
# Requires (db is a mongoskin instance)
fluent = require("fluent-async")
db = require "./db"

# Async functions are defined outside of any scope
getUser = (id, projection, callback) ->
  db.users.findById id, projection, callback

getFriends = (user, projection, callback) ->
  db.users.findItems {email:$in:user.profile.friends}, projection, callback

getMessages = (user, callback) ->
  db.messages.findItems {userId:user._id}, callback

# Synchronous operations can be defined like this
merge = (user, friends, messages, callback) ->
  user.friends = friends
  user.messages = messages
  callback null, user

# Now we create the function that wraps all these calls together
getAll = fluent.create()
  .strict()
  .data("projection", {profile:1})
  .add({getUser}, "id","projection")
  .add({getFriends}, "getUser", "projection")
  .add({getMessages}, "getUser")
  .add({merge}, "getUser", "getFriends", "getMessages")
  .expects("merge")
  .generate("id")

# Here's an example express route showing how we can re-use the generated function
getUserRequest = (req, res) ->
  getAll req.params.id, (err, user) ->
    if err
      res.send 500
    else
      res.json user

```

The nice thing with the above code is that we only have to check for errors in a single place.
Also we've not had to make any special wrapping functions. Our async functions have pure business logic,
there is no configuration specific to our async library in our actual functions.

Compare this to how the code would like using straight `async.auto` below.
With this version I have to write custom wrapping code around the functions to get access to any
initial data and access to the results of any of the produced functions. There is now a mix of
business logic and implementation logic in my functions. There is also more wrapped functions
that are generated at each pass of the function, resulting in slower code.


```coffeescript

# Requires (db is a mongoskin instance)
async = require "async"
db = require "./db"

# Async functions are defined outside of any scope
getUser = (projection, id) ->
  (callback) ->
    db.users.findById id, projection, callback


getFriends = (user, projection, callback) ->
  (projection) ->
    (callback, results) ->
      db.users.findItems {email:$in:results.getUser.profile.friends}, projection, callback

getMessages = (callback, results) ->
  db.messages.findItems {userId:results.getUser._id}, callback

# Synchronous operations can be defined like this
merge = (callback, results) ->
  user = results.getUser
  user.friends = results.getFriends
  user.messages = results.getMessages
  callback null, user

getAll = (id, callback) ->
  projection = {profile:1}
  async.auto
    getUser:getUser(projection, id)
    getFriends: ["getUser", getFriends(projection)]
    getMessages: ["getUser", getMessages]
    merge: ["getUser","getMessages", "getFriends", merge]
  , (err, results) ->
    if err then return callback(err)
    callback null, results.merge




# Here's an example express route showing how we can re-use the generated function
getUserRequest = (req, res) ->
  getAll req.params.id, (err, user) ->
    if err
      res.send 500
    else
      res.json user


```




