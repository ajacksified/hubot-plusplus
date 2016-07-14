# Description:
#   Give or take away points. Keeps track and even prints out graphs.
#
# Dependencies:
#   "underscore": ">= 1.0.0"
#   "clark": "0.0.6"
#
# Configuration:
#   HUBOT_PLUSPLUS_KEYWORD: the keyword that will make hubot give the
#   score for a name and the reasons. For example you can set this to
#   "score|karma" so hubot will answer to both keywords.
#   If not provided will default to 'score'.
#
# Commands:
#   <name>++ [<reason>] - Increment score for a name (for a reason)
#   <name>-- [<reason>] - Decrement score for a name (for a reason)
#   hubot score <name> - Display the score for a name and some of the reasons
#   hubot top <amount> - Display the top scoring <amount>
#   hubot bottom <amount> - Display the bottom scoring <amount>
#   hubot erase <name> [<reason>] - Remove the score for a name (for a reason)
#
# URLs:
#   /hubot/scores[?name=<name>][&direction=<top|botton>][&limit=<10>]
#
# Author:
#   ajacksified


_ = require('underscore')
clark = require('clark')
querystring = require('querystring')
ScoreKeeper = require('./scorekeeper')

module.exports = (robot) ->
  scoreKeeper = new ScoreKeeper(robot)
  scoreKeyword   = process.env.HUBOT_PLUSPLUS_KEYWORD or 'score'
  reasonsKeyword = process.env.HUBOT_PLUSPLUS_REASONS or 'raisins'

  # sweet regex bro
  robot.hear ///
    # from beginning of line
    ^
    # the thing being upvoted, which is any number of words and spaces
    ([\s\w'@.\-:\u3040-\u30FF\uFF01-\uFF60\u4E00-\u9FA0]*)
    # allow for spaces after the thing being upvoted (@user ++)
    \s*
    # the increment/decrement operator ++ or --
    (\+\+|--|—)
    # optional reason for the plusplus
    (?:\s+(?:for|because|cause|cuz|as)\s+(.+))?
    $ # end of line
  ///i, (msg) ->
    # let's get our local vars in place
    [dummy, name, operator, reason] = msg.match
    from = msg.message.user.name.toLowerCase()
    room = msg.message.room

    # do some sanitizing
    reason = reason?.trim().toLowerCase()

    if name
      if name.charAt(0) == ':'
        name = (name.replace /(^\s*@)|([,\s]*$)/g, '').trim().toLowerCase()
      else
        name = (name.replace /(^\s*@)|([,:\s]*$)/g, '').trim().toLowerCase()

    # check whether a name was specified. use MRU if not
    unless name? && name != ''
      [name, lastReason] = scoreKeeper.last(room)
      reason = lastReason if !reason? && lastReason?

    # do the {up, down}vote, and figure out what the new score is
    [score, reasonScore] = if operator == "++"
              scoreKeeper.add(name, from, room, reason)
            else
              scoreKeeper.subtract(name, from, room, reason)

    # if we got a score, then display all the things and fire off events!
    if score?
      message = if reason?
                  if reasonScore == 1 or reasonScore == -1
                    if score == 1 or score == -1
                      "#{name} has #{score} point for #{reason}."
                    else
                      "#{name} has #{score} points, #{reasonScore} of which is for #{reason}."
                  else
                    "#{name} has #{score} points, #{reasonScore} of which are for #{reason}."
                else
                  if score == 1
                    "#{name} has #{score} point"
                  else
                    "#{name} has #{score} points"


      msg.send message

      robot.emit "plus-one", {
        name:      name
        direction: operator
        room:      room
        reason:    reason
        from:      from
      }

  robot.respond ///
    (?:erase )
    # thing to be erased
    ([\s\w'@.-:\u3040-\u30FF\uFF01-\uFF60\u4E00-\u9FA0]*)
    # optionally erase a reason from thing
    (?:\s+(?:for|because|cause|cuz)\s+(.+))?
    $ # eol
  ///i, (msg) ->
    [__, name, reason] = msg.match
    from = msg.message.user.name.toLowerCase()
    user = msg.envelope.user
    room = msg.message.room
    reason = reason?.trim().toLowerCase()

    if name
      if name.charAt(0) == ':'
        name = (name.replace /(^\s*@)|([,\s]*$)/g, '').trim().toLowerCase()
      else
        name = (name.replace /(^\s*@)|([,:\s]*$)/g, '').trim().toLowerCase()

    isAdmin = @robot.auth?.hasRole(user, 'plusplus-admin') or @robot.auth?.hasRole(user, 'admin')

    if not @robot.auth? or isAdmin
      erased = scoreKeeper.erase(name, from, room, reason)
    else
      return msg.reply "Sorry, you don't have authorization to do that."

    if erased?
      message = if reason?
                  "Erased the following reason from #{name}: #{reason}"
                else
                  "Erased points for #{name}"
      msg.send message

  # Catch the message asking for the score.
  robot.respond new RegExp("(?:" + scoreKeyword + ") (for\s)?(.*)", "i"), (msg) ->
    name = msg.match[2].trim().toLowerCase()

    if name
      if name.charAt(0) == ':'
        name = (name.replace /(^\s*@)|([,\s]*$)/g, '')
      else
        name = (name.replace /(^\s*@)|([,:\s]*$)/g, '')

    console.log(name)

    score = scoreKeeper.scoreForUser(name)
    reasons = scoreKeeper.reasonsForUser(name)

    reasonString = if typeof reasons == 'object' && Object.keys(reasons).length > 0
                     "#{name} has #{score} points. Here are some #{reasonsKeyword}:" +
                     _.reduce(reasons, (memo, val, key) ->
                       memo += "\n#{key}: #{val} points"
                     , "")
                   else
                     "#{name} has #{score} points."

    msg.send reasonString

  robot.respond /(top|bottom) (\d+)/i, (msg) ->
    amount = parseInt(msg.match[2]) || 10
    message = []

    tops = scoreKeeper[msg.match[1]](amount)

    if tops.length > 0
      for i in [0..tops.length-1]
        message.push("#{i+1}. #{tops[i].name} : #{tops[i].score}")
    else
      message.push("No scores to keep track of yet!")

    if(msg.match[1] == "top")
      graphSize = Math.min(tops.length, Math.min(amount, 20))
      message.splice(0, 0, clark(_.first(_.pluck(tops, "score"), graphSize)))

    msg.send message.join("\n")

  robot.router.get "/#{robot.name}/normalize-points", (req, res) ->
    scoreKeeper.normalize((score) ->
      if score > 0
        score = score - Math.ceil(score / 10)
      else if score < 0
        score = score - Math.floor(score / 10)

      score
    )

    res.end JSON.stringify('done')

  robot.router.get "/#{robot.name}/scores", (req, res) ->
    query = querystring.parse(req._parsedUrl.query)

    if query.name
      obj = {}
      obj[query.name] = scoreKeeper.scoreForUser(query.name)
      res.end JSON.stringify(obj)
    else
      direction = query.direction || "top"
      amount = query.limit || 10

      tops = scoreKeeper[direction](amount)

      res.end JSON.stringify(tops, null, 2)
