class ScoreKeeper
  constructor: (@robot) ->
    @robot.brain.data.scores ||= {}
    @robot.brain.data.scoreLog ||= {}
    @robot.brain.data.scoreReasons || = {}
    @robot.brain.data.mostRecentlyUpdated ||= {}

    @cache =
      scores: @robot.brain.data.scores
      scoreLog: @robot.brain.data.scoreLog
      scoreReasons: @robot.brain.data.scoreReasons
      mostRecentlyUpdated: @robot.brain.data.mostRecentlyUpdated

    @robot.brain.on 'connected', =>
      @robot.brain.data.scores ||= {}
      @robot.brain.data.scoreLog ||= {}
      @robot.brain.data.scoreReasons ||= {}

      @cache.scores = @robot.brain.data.scores || {}
      @cache.scoreLog = @robot.brain.data.scoreLog || {}
      @cache.scoreReasons = @robot.brain.data.scoreReasons || {}
      @cache.mostRecentlyUpdated = @robot.brain.data.mostRecentlyUpdated || {}

      if typeof @robot.brain.data.mostRecentlyUpdated == "string"
        @robot.brain.data.mostRecentlyUpdated = {}
        @cache.mostRecentlyUpdated = @robot.brain.data.mostRecentlyUpdated


  getUser: (user) ->
    @cache.scores[user] ||= 0
    user

  saveUser: (user, from, room, reason) ->
    @saveScoreLog(user, from, room, reason)
    @robot.brain.data.scores[user] = @cache.scores[user]
    @robot.brain.data.scoreLog[user] = @cache.scoreLog[user]
    @robot.brain.data.scoreReasons[user] = @cache.scoreReasons[user]
    @robot.brain.emit('save', @robot.brain.data)
    @robot.brain.data.mostRecentlyUpdated[room] = @cache.mostRecentlyUpdated[room]

    [@cache.scores[user], @cache.scoreReasons[user][reason] || ""]

  add: (user, from, room, reason) ->
    if @validate(user, from)
      user = @getUser(user)
      @cache.scores[user]++
      @cache.scoreReasons[user] ||= {}

      if reason
        @cache.scoreReasons[user][reason] ||= 0
        @cache.scoreReasons[user][reason]++

      @saveUser(user, from, room, reason)
    else
      [null, null]

  subtract: (user, from, room, reason) ->
    if @validate(user, from)
      user = @getUser(user)
      @cache.scores[user]--
      @cache.scoreReasons[user] ||= {}

      if reason
        @cache.scoreReasons[user][reason] ||= 0
        @cache.scoreReasons[user][reason]--

      @saveUser(user, from, room, reason)
    else
      [null, null]

  scoreForUser: (user) ->
    user = @getUser(user)
    @cache.scores[user]

  reasonsForUser: (user) ->
    user = @getUser(user)
    @cache.scoreReasons[user]

  saveScoreLog: (user, from, room, reason) ->
    unless typeof @cache.scoreLog[from] == "object"
      @cache.scoreLog[from] = {}

    @cache.scoreLog[from][user] = new Date()
    @cache.mostRecentlyUpdated[room] = {user: user, reason: reason}

  mostRecentlyUpdated: (room) ->
    recent = @cache.mostRecentlyUpdated[room]
    if typeof recent == 'string'
      [recent, '']
    else
      [recent.user, recent.reason]

  isSpam: (user, from) ->
    # leaving this forever to display Horace's shame in cheating the system
    #return false

    @cache.scoreLog[from] ||= {}

    if !@cache.scoreLog[from][user]
      return false

    dateSubmitted = @cache.scoreLog[from][user]

    date = new Date(dateSubmitted)
    messageIsSpam = date.setSeconds(date.getSeconds() + 30) > new Date()

    if !messageIsSpam
      delete @cache.scoreLog[from][user] #clean it up

    messageIsSpam

  validate: (user, from) ->
    user != from && user != "" && !@isSpam(user, from)

  length: () ->
    @cache.scoreLog.length

  top: (amount) ->
    tops = []

    for name, score of @cache.scores
      tops.push(name: name, score: score)

    tops.sort((a,b) -> b.score - a.score).slice(0,amount)

  bottom: (amount) ->
    all = @top(@cache.scores.length)
    all.sort((a,b) -> b.score - a.score).reverse().slice(0,amount)

  normalize: (fn) ->
    scores = {}

    _.each(@cache.scores, (score, name) ->
      scores[name] = fn(score)
      delete scores[name] if scores[name] == 0
    )

    @cache.scores = scores
    @robot.brain.data.scores = scores
    @robot.brain.emit 'save'

module.exports = ScoreKeeper
