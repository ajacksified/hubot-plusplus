hubot-plusplus
==============

Give (or take away) points from people and things, all from the comfort of your
personal Hubot.

Note: don't make changes here; make changes to [the official repository](https://github.com/hubot-scripts/hubot-plusplus) instead.

API
---

* `thing++` - add a point to `thing`
* `++` - add a point to the most previously voted-on thing
* `thing++ for stuff` - keep track of why you gave thing points
* `thing--` - remove a point from `thing`
* `--` - remove a point from the most previously voted-on thing
* `thing-- for stuff` - keep track of why you removed thing points
* `hubot erase thing` - erase thing from scoreboard (permanently deletes thing from memory)
* `hubot erase thing for reason` erase given reason from thing's score board (does not deduct from total score)
* `hubot top 10` - show the top 10, with a graph of points
* `hubot score thing` - check the score for and reasons for `thing`

Uses Hubot brain. Also exposes the following events, should you wish to hook
into it to do things like print out funny gifs for point streaks:

```coffeescript
robot.emit "plus-one", {
  name: 'Jack'
  direction: '++' # (or --)
  room: 'chatRoomAlpha'
  reason: 'being awesome'
}
```

## Installation

Run the following command 

    $ npm install hubot-plusplus

Then to make sure the dependencies are installed:

    $ npm install

To enable the script, add a `hubot-plusplus` entry to the `external-scripts.json`
file (you may need to create this file).

    ["hubot-plusplus"]
