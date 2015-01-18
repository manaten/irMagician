# Description:
#  Force hubot only hearing messages of manaten.
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   None
#

module.exports = (robot) ->
  robot.hear /.*/, (msg) ->
    if msg.envelope.user.name isnt 'manaten'
      msg.finish()
