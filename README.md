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
  .add("getUser", getUser, "id", "projection") // getUser will be called with id, projection, callback
  .add("getFriends", getFriends, "getUser") // getFriends will be called with result of getUser and a callback
  .add("getMessages", getMessages, "getUser") // will be run parallel to above
  .run(render, "getMessages", "getFriends") // render function will be called with err, messages, friends

```

Here's another example in coffee-script (taking advantage of easy object creation)

```coffeescript
fluent = require("fluent-async")
fluent.create({id:1})
    .domain() # enable domains support (experimental)
    .data("projection", {profile:1})
    .add({getUser}, ["id","projection"]) # dependencies can also be supplied as an array
    .add({getFriends}, "getUser")
    .add({getMessages}, "getUser")
    .run(render, "getMessages", "getFriends")

```

### Domains

I've added this in - experimental for now, still requires more testing

### Ensuring callbacks are only called once

Some of the harder to find bugs that I've encountered using node is when you trigger a callback more than once
This is normally due to an error in your code path, but it often ends up having weird side effects and might
not always be noticed.

To help avoid these bugs, this library will throw an error if you attempt to call one of the supplied callbacks
more than once.

### Tests

There are some initial Mocha tests, more will be added later.
