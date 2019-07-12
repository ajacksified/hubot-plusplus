# Description:
#   Helper class responsible for storing scores
#
# Dependencies:
#
# Configuration:
#
# Commands:
#
# Author:
#   ajacksified
class ScoreKeeper
  constructor: (@robot) ->
    storageLoaded = =>
      @storage = @robot.brain.data.plusPlus ||= {
        scores: {}
        log: {}
        reasons: {}
        last: {}
      }
      if typeof @storage.last == "string"
        @storage.last = {}

      @robot.logger.debug "Plus Plus Data Loaded: " + JSON.stringify(@storage, null, 2)
    @robot.brain.on "loaded", storageLoaded
    storageLoaded() # just in case storage was loaded before we got here


  getRecipient: (recipient) ->
    @storage.scores[recipient.toLowerCase()] ||= 0
    @storage.reasons[recipient.toLowerCase()] ||= {}
    recipient

  saveRecipient: (recipient, sender, room, reason) ->
    @saveScoreLog(recipient, sender, room, reason)
    @robot.brain.save()

    [@storage.scores[recipient.toLowerCase()], @storage.reasons[recipient.toLowerCase()][reason?.toLowerCase()] || "none"]

  add: (recipient, sender, room, reason) ->
    if @validate(recipient, sender)
      recipient = @getRecipient(recipient)
      @storage.scores[recipient.toLowerCase()]++
      @storage.reasons[recipient.toLowerCase()] ||= {}

      if reason
        @storage.reasons[recipient.toLowerCase()][reason.toLowerCase()] ||= 0
        @storage.reasons[recipient.toLowerCase()][reason.toLowerCase()]++

      @saveRecipient(recipient, sender, room, reason)
    else
      [null, null]

  subtract: (recipient, sender, room, reason) ->
    if @validate(recipient, sender)
      recipient = @getRecipient(recipient)
      @storage.scores[recipient.toLowerCase()]--
      @storage.reasons[recipient.toLowerCase()] ||= {}

      if reason
        @storage.reasons[recipient.toLowerCase()][reason.toLowerCase()] ||= 0
        @storage.reasons[recipient.toLowerCase()][reason.toLowerCase()]--

      @saveRecipient(recipient, sender, room, reason)
    else
      [null, null]

  erase: (recipient, sender, room, reason) ->
    recipient = @getRecipient(recipient)

    if reason
      delete @storage.reasons[recipient.toLowerCase()][reason.toLowerCase()]
      @saveRecipient(recipient, sender.name, room)
      return true
    else
      delete @storage.scores[recipient.toLowerCase()]
      delete @storage.reasons[recipient.toLowerCase()]
      return true

    false

  scoreForUser: (recipient) ->
    recipient = @getRecipient(recipient)
    @storage.scores[recipient.toLowerCase()]

  reasonsForUser: (recipient) ->
    recipient = @getRecipient(recipient)
    @storage.reasons[recipient.toLowerCase()]

  saveScoreLog: (recipient, sender, room, reason) ->
    unless typeof @storage.log[sender] == "object"
      @storage.log[sender] = {}

    @storage.log[sender][recipient] = new Date()
    @storage.last[room] = {recipient: recipient, reason: reason}

  last: (room) ->
    last = @storage.last[room]
    if typeof last == 'string'
      [last, '']
    else
      [last.recipient, last.reason]

  isSpam: (recipient, sender) ->
    @storage.log[sender] ||= {}

    if !@storage.log[sender][recipient]
      return false

    dateSubmitted = @storage.log[sender][recipient]

    date = new Date(dateSubmitted)
    messageIsSpam = date.setSeconds(date.getSeconds() + 5) > new Date()

    if !messageIsSpam
      delete @storage.log[sender][recipient] #clean it up

    messageIsSpam

  validate: (recipient, sender) ->
    recipient != sender && recipient != "" && !@isSpam(recipient, sender)

  length: () ->
    @storage.log.length

  top: (amount) ->
    tops = []

    for name, score of @storage.scores
      tops.push(name: name, score: score)

    tops.sort((a,b) -> b.score - a.score).slice(0,amount)

  bottom: (amount) ->
    all = @top(@storage.scores.length)
    all.sort((a,b) -> b.score - a.score).reverse().slice(0,amount)

  normalize: (fn) ->
    scores = {}

    _.each(@storage.scores, (score, name) ->
      scores[name] = fn(score)
      delete scores[name] if scores[name] == 0
    )

    @storage.scores = scores
    @robot.brain.save()

module.exports = ScoreKeeper
