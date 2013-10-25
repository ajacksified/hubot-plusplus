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

    it 'adds points to a user for a reason', ->
      s = new ScoreKeeper(robotStub)
      r = s.subtract('to', 'from', 'room', 'because points')
      expect(r).to.deep.equal([-1, -1])

    it 'does not allow spamming points', ->
      s = new ScoreKeeper(robotStub)
      r = s.subtract('to', 'from', 'room', 'because points')
      r2 = s.subtract('to', 'from', 'room', 'because points')
      expect(r2).to.deep.equal([null, null])

    it 'adds more points to a user for a reason', ->
      s = new ScoreKeeper(robotStub)
      r = s.subtract('to', 'from', 'room', 'because points')
      r = s.subtract('to', 'another-from', 'room', 'because points')
      expect(r).to.deep.equal([-2, -2])

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
