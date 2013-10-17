
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


