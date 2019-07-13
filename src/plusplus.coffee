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
#   HUBOT_PLUSPLUS_REASON_CONJUNCTIONS: a pipe separated list of conjuntions to
#   be used when specifying reasons. The default value is
#   "for|because|cause|cuz|as", so it can be used like:
#   "foo++ for being awesome" or "foo++ cuz they are awesome".
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
  reasonConjunctions = process.env.HUBOT_PLUSPLUS_CONJUNCTIONS or 'for|because|cause|cuz|as'

  # set _only_ the roles you want protected with hubot-auth roles
  # you probably don't want most of these, but they're available just in case
  roles = {
    add: process.env.HUBOT_PLUSPLUS_ROLE_ADD
    subtract: process.env.HUBOT_PLUSPLUS_ROLE_SUBTRACT
    score: process.env.HUBOT_PLUSPLUS_ROLE_SCORE
    top: process.env.HUBOT_PLUSPLUS_ROLE_TOP
    bottom: process.env.HUBOT_PLUSPLUS_ROLE_BOTTOM
    erase: process.env.HUBOT_PLUSPLUS_ROLE_ERASE
  }

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
    (?:\s+(?:#{reasonConjunctions})\s+(.+))?
    $ # end of line
  ///i, (msg) ->
    # let's get our local vars in place
    [dummy, recipient, operator, reason] = msg.match
    sender = msg.message.user.name
    user = msg.envelope.user
    room = msg.message.room

    operation = if operator == "++"
                  "add"
                else
                  "subtract"

    canModify = if @robot.auth?
                  if roles[operation]?
                    @robot.auth.hasRole(user, roles[operation])
                  else true
                else true

    unless canModify
      return

    # do some sanitizing
    reason = reason?.trim()

    if recipient
      if recipient.charAt(0) == ':'
        recipient = (recipient.replace /(^\s*@)|([,\s]*$)/g, '').trim()
      else
        recipient = (recipient.replace /(^\s*@)|([,:\s]*$)/g, '').trim()

    # check whether a recipient was specified. use most recent if not
    unless recipient? && recipient != ''
      [recipient, lastReason] = scoreKeeper.last(room)
      reason = lastReason if !reason? && lastReason?

    # do the {up, down}vote, and figure out what the new score is
    [score, reasonScore] = if operator == "++"
              scoreKeeper.add(recipient, sender, room, reason)
            else
              scoreKeeper.subtract(recipient, sender, room, reason)

    # if we got a score, then display all the things and fire off events!
    if score?
      message = if reason?
                  if reasonScore == 1 or reasonScore == -1
                    if score == 1 or score == -1
                      "#{recipient} has #{score} point for #{reason}"
                    else
                      "#{recipient} has #{score} points, #{reasonScore} of which is for #{reason}"
                  else
                    "#{recipient} has #{score} points, #{reasonScore} of which are for #{reason}"
                else
                  if score == 1
                    "#{recipient} has #{score} point"
                  else
                    "#{recipient} has #{score} points"


      msg.send message

      robot.emit "plus-one", {
        name:      recipient
        direction: operator
        room:      room
        reason:    reason
        from:      sender
      }

  robot.respond ///
    (?:erase )
    # thing to be erased
    ([\s\w'@.-:\u3040-\u30FF\uFF01-\uFF60\u4E00-\u9FA0]*)
    # optionally erase a reason from thing
    (?:\s+(?:for|because|cause|cuz)\s+(.+))?
    $ # eol
  ///i, (msg) ->
    [__, recipient, reason] = msg.match
    sender = msg.message.user.name.toLowerCase()
    user = msg.envelope.user
    room = msg.message.room
    reason = reason?.trim().toLowerCase()

    canErase =
      if @robot.auth?
        if roles.erase?
          @robot.auth.hasRole(user, roles.erase)
        else true
      else true
    console.log(canErase, 'canErase')

    unless canErase
      return msg.reply "Sorry, you don't have authorization to do that."

    if recipient
      if recipient.charAt(0) == ':'
        recipient = (recipient.replace /(^\s*@)|([,\s]*$)/g, '').trim().toLowerCase()
      else
        recipient = (recipient.replace /(^\s*@)|([,:\s]*$)/g, '').trim().toLowerCase()

    erased = scoreKeeper.erase(recipient, sender, room, reason)

    if erased?
      message = if reason?
                  "Erased the following reason from #{recipient}: #{reason}"
                else
                  "Erased points for #{recipient}"
      msg.send message

  # Catch the message asking for the score.
  robot.respond new RegExp("(?:" + scoreKeyword + ") (for\s)?(.*)", "i"), (msg) ->
    recipient = msg.match[2].trim().toLowerCase()
    user = msg.envelope.user

    canScore =
      if @robot.auth?
        if roles.score?
          @robot.auth.hasRole(user, roles.score)
        else true
      else true
    console.log('canscore', canScore)

    unless canScore
      return

    if recipient
      if recipient.charAt(0) == ':'
        recipient = (recipient.replace /(^\s*@)|([,\s]*$)/g, '')
      else
        recipient = (recipient.replace /(^\s*@)|([,:\s]*$)/g, '')

    score = scoreKeeper.scoreForUser(recipient)
    reasons = scoreKeeper.reasonsForUser(recipient)

    reasonString =
      if typeof reasons == 'object' && Object.keys(reasons).length > 0
        "#{recipient} has #{score} points. Here are some #{reasonsKeyword}:" +
          _.reduce(reasons, (memo, val, key) ->
            memo += "\n#{key}: #{val} points"
          , "")
      else
        "#{recipient} has #{score} points."

    msg.send reasonString

  robot.respond /(top|bottom) (\d+)/i, (msg) ->
    amount = parseInt(msg.match[2]) || 10
    direction = msg.match[1]
    user = msg.envelope.user
    message = []

    canScoreboard =
      if @robot.auth?
        if roles[direction]?
          @robot.auth.hasRole(user, roles[direction])
        else true
      else true

    tops = scoreKeeper[direction](amount)

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
