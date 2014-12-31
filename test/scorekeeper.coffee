chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'

expect = chai.expect

ScoreKeeper = require '../src/scorekeeper.coffee'

robotStub = {}

describe 'ScoreKeeper', ->
  beforeEach ->
    robotStub =
      brain:
        data: { }
        on: ->
        emit: ->

  describe 'adding', ->
    it 'adds points to a user', ->
      s = new ScoreKeeper(robotStub)
      r = s.add('to', 'from', 'room')
      expect(r[0]).to.equal(1)

    it 'adds points to a user for a reason', ->
      s = new ScoreKeeper(robotStub)
      r = s.add('to', 'from', 'room', 'because points')
      expect(r).to.deep.equal([1, 1])

    it 'does not allow spamming points', ->
      s = new ScoreKeeper(robotStub)
      r = s.add('to', 'from', 'room', 'because points')
      r2 = s.add('to', 'from', 'room', 'because points')
      expect(r2).to.deep.equal([null, null])

    it 'adds more points to a user for a reason', ->
      s = new ScoreKeeper(robotStub)
      r = s.add('to', 'from', 'room', 'because points')
      r = s.add('to', 'another-from', 'room', 'because points')
      expect(r).to.deep.equal([2, 2])

  describe 'subtracting', ->
    it 'adds points to a user', ->
      s = new ScoreKeeper(robotStub)
      r = s.subtract('to', 'from', 'room')
      expect(r[0]).to.equal(-1)

    it 'subtracts points from a user for a reason', ->
      s = new ScoreKeeper(robotStub)
      r = s.subtract('to', 'from', 'room', 'because points')
      expect(r).to.deep.equal([-1, -1])

    it 'does not allow spamming points', ->
      s = new ScoreKeeper(robotStub)
      r = s.subtract('to', 'from', 'room', 'because points')
      r2 = s.subtract('to', 'from', 'room', 'because points')
      expect(r2).to.deep.equal([null, null])

    it 'subtracts more points from a user for a reason', ->
      s = new ScoreKeeper(robotStub)
      r = s.subtract('to', 'from', 'room', 'because points')
      r = s.subtract('to', 'another-from', 'room', 'because points')
      expect(r).to.deep.equal([-2, -2])

  describe 'erasing', ->
    it 'erases a reason from a user', ->
      s = new ScoreKeeper(robotStub)
      p = s.add('to', 'from', 'room', 'reason')
      r = s.erase('to', 'from', 'room', 'reason')
      expect(r).to.deep.equal(true)
      rs = s.reasonsForUser('to')
      expect(rs.reason).to.equal(undefined)

    it 'erases a user from the scoreboard', ->
      s = new ScoreKeeper(robotStub)
      p = s.add('to', 'from', 'room', 'reason')
      expect(p).to.deep.equal([1, 1])
      r = s.erase('to', 'from', 'room')
      expect(r).to.equal(true)
      p2 = s.scoreForUser('to')
      expect(p2).to.equal(0)

  describe 'scores', ->
    it 'returns the score for a user', ->
      s = new ScoreKeeper(robotStub)
      s.add('to', 'from', 'room')
      r = s.scoreForUser('to')
      expect(r).to.equal(1)

    it 'returns the reasons for a user', ->
      s = new ScoreKeeper(robotStub)
      s.add('to', 'from', 'room', 'because points')
      r = s.reasonsForUser('to')
      expect(r).to.deep.equal({ 'because points': 1 })
