fluent = require("fluent-async")
db = require "./db"

getUser = (id, projection, callback) ->
  db.users.findById id, projection, callback

getFriends = (user, projection, callback) ->
  db.users.findItems {email:$in:user.profile.friends}, projection, callback

getMessages = (user, callback) ->
  db.messages.findItems {userId:user._id}, callback

merge = (user, friends, messages, callback) ->
  user.friends = friends
  user.messages = messages
  callback null, user

getAll = fluent.create()
  .strict()
  .data("projection", {profile:1})
  .add({getUser}, ["id","projection"]) # dependencies can also be supplied as an array
  .add({getFriends}, "getUser", "projection")
  .add({getMessages}, "getUser")
  .add({merge}, "getUser", "getFriends", "getMessages")
  .generate("merge")

server.get "/user/:id", (req, res) ->
  getAll {id:req.params.id}, (err, user) ->
    if err
      res.send 500
    else
      res.json user
