# Description:
#   Adapter for Hubot to communicate on Discord
#
# Commands:
#   None
#
# Configuration:
#   HUBOT_DISCORD_TOKEN          - authentication token for bot
#   HUBOT_DISCORD_STATUS_MSG     - Status message to set for "currently playing game"
#
# Notes:
#
try
    {Robot, Adapter, EnterMessage, LeaveMessage, TopicMessage, TextMessage, User}  = require 'hubot'
catch
    prequire = require( 'parent-require' )
    {Robot, Adapter, EnterMessage, LeaveMessage, TopicMessage, TextMessage, User}  = prequire 'hubot'

Discord             = require "discord.js"
TextChannel         = Discord.TextChannel

#Settings
currentlyPlaying    = process.env.HUBOT_DISCORD_STATUS_MSG || ''

class DiscordBot extends Adapter
     constructor: (robot)->
        super
        @rooms = {}
        if not process.env.HUBOT_DISCORD_TOKEN?
          @robot.logger.error "Error: Environment variable named `HUBOT_DISCORD_TOKEN` required"
          return

     run: ->
        @options =
            token: process.env.HUBOT_DISCORD_TOKEN

        @client = new Discord.Client {autoReconnect: true, fetch_all_members: true, api_request_method: 'burst', ws: {compress: yes, large_threshold: 1000}}
        @robot.client = @client
        @client.on 'ready', @.ready
        @client.on 'message', @.message
        @client.on 'disconnected', @.disconnected

        @client.login(@options.token).catch(@robot.logger.error)


     ready: =>
        @robot.logger.info "Logged in: #{@client.user.username}##{@client.user.discriminator}"
        @robot.name = @client.user.username
        @robot.logger.info "Robot Name: #{@robot.name}"
        @emit "connected"

        #post-connect actions
        @rooms[channel.id] = channel for channel in @client.channels
        @client.user.setStatus('online', currentlyPlaying)
          .then(@robot.logger.debug("Status set to #{currentlyPlaying}"))
          .catch(@robot.logger.error)

     message: (message) =>
        # ignore messages from myself
        return if message.author.id == @client.user.id
        user                      = @robot.brain.userForId message.author.id
        user.room                 = message.channel.id
        user.name                 = message.author.username
        user.discriminator        = message.author.discriminator
        user.id                   = message.author.id

        @rooms[message.channel.id]?= message.channel

        text = message.cleanContent

        if (message?.channel instanceof Discord.DMChannel)
          text = "#{@robot.name}: #{text}" if not text.match new RegExp( "^@?#{@robot.name}" )

        @robot.logger.debug text
        @receive new TextMessage( user, text, message.id )

     disconnected: =>
        @robot.logger.info "#{@robot.name} Disconnected, will auto reconnect soon..."

     send: (envelope, messages...) ->
        for message in messages
         @sendMessage envelope.room, message

     reply: (envelope, messages...) ->
        for message in messages
          @sendMessage envelope.room, "<@#{envelope.user.id}> #{message}"

     sendMessage: (channelId, message) ->
        errorHandle = (err) ->
          robot.logger.error "Error sending: #{message}\r\n#{err}"


        #Padded blank space before messages to comply with https://github.com/meew0/discord-bot-best-practices
        zSWC              = "\u200B"
        message = zSWC+message

        robot = @robot
        sendChannelMessage = (channel, message) ->
          clientUser = robot?.client?.user
          isText = channel != null && channel.type == 'text'
          permissions = isText && channel.permissionsFor(clientUser)

          hasPerm = if isText then (permissions != null && permissions.hasPermission("SEND_MESSAGES")) else channel.type != 'text'
          if(hasPerm)
            channel.sendMessage(message, {split: true})
              .then (msg) ->
                robot.logger.debug "SUCCESS! Message sent to: #{channel.id}"
              .catch (err) ->
                robot.logger.debug "Error sending: #{message}\r\n#{err}"
                if(process.env.HUBOT_OWNER)
                  owner = robot.client.users.get(process.env.HUBOT_OWNER)
                  owner.sendMessage("Couldn't send message to #{channel.name} (#{channel}) in #{channel.guild.name}, contact #{channel.guild.owner}.\r\n#{error}")
                    .then (msg) ->
                      robot.logger.debug "SUCCESS! Message sent to: #{owner.id}"
                    .catch (err) ->
                        robot.logger.debug "Error sending: #{message}\r\n#{err}"
          else
            robot.logger.debug "Can't send message to #{channel.name}, permission denied"
            if(process.env.HUBOT_OWNER)
              owner = robot.client.users.get(process.env.HUBOT_OWNER)  
              owner.sendMessage("Couldn't send message to #{channel.name} (#{channel}) in #{channel.guild.name}, contact #{channel.guild.owner} to check permissions")
                .then (msg) ->
                  robot.logger.debug "SUCCESS! Message sent to: #{owner.id}"
                .catch (err) ->
                    robot.logger.debug "Error sending: #{message}\r\n#{err}"


        sendUserMessage = (user, message) ->
          user.sendMessage(message, {split: true})
            .then (msg) ->
              robot.logger.debug "SUCCESS! Message sent to: #{user.id}"
            .catch (err) ->
              robot.logger.debug "Error sending: #{message}\r\n#{err}"


        #@robot.logger.debug "#{@robot.name}: Try to send message: \"#{message}\" to channel: #{channelId}"

        if @rooms[channelId]? # room is already known and cached
            sendChannelMessage @rooms[channelId], message
        else # unknown room, try to find it
            channels = @client.channels.filter (channel) -> channel.id == channelId
            if channels.first()?
                sendChannelMessage channels.first(), message
            else if @client.users.get(channelId)?
                sendUserMessage @client.users.get(channelId), message
            else
              @robot.logger.debug "Unknown channel id: #{channelId}"


     channelDelete: (channel, client) ->
        roomId = channel.id
        user               = new User client.user.id
        user.room          = roomId
        user.name          = client.user.username
        user.discriminator = client.user.discriminator
        user.id            = client.user.id
        @robot.logger.info "#{user.name}#{user.discriminator} leaving #{roomId} after a channel delete"
        @receive new LeaveMessage user, null, null

     guildDelete: (guild, client) ->
      serverId = guild.id
      roomIds = (channel.id for channel in guild.channels)
      for room of rooms
        user = new User client.user.id
        user.room = room.id
        user.name = client.user.username
        user.discriminator = client.user.discriminator
        user.id = client.user.id
        @robot.logger.info "#{user.name}#{user.discriminator} leaving #{roomId} after a guild delete"
        @receive new LeaveMessage(user, null, null)


exports.use = (robot) ->
    new DiscordBot robot
