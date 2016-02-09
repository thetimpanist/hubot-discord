
module.exports = (robot) ->

  # listen for DM server invites
  if robot.adapterName is 'discord'
    robot.hear /https:\/\/discord.gg\/(.*)/, (res) ->
        # you can also send the entire link as is
        robot.adapter.join( res.match[1],
            ( error, server ) ->
                if server
                    res.reply "Joined Server: " + server.id
                else
                    res.reply error
            )
