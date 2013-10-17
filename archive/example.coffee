
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


