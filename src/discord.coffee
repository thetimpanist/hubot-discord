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
    {Robot, Response, Adapter, EnterMessage, LeaveMessage, TopicMessage, TextMessage, User}  = require 'hubot'
catch
    prequire = require( 'parent-require' )
    {Robot, Response, Adapter, EnterMessage, LeaveMessage, TopicMessage, TextMessage, User}  = prequire 'hubot'

Discord             = require "discord.js"
TextChannel         = Discord.TextChannel
ReactionMessage     = require "./reaction_message"

#Settings
currentlyPlaying    = process.env.HUBOT_DISCORD_STATUS_MSG || ''

Robot::react = (matcher, options, callback) ->
  # this function taken from the hubot-slack api
  matchReaction = (msg) -> msg instanceof ReactionMessage

  if arguments.length == 1
    return @listen matchReaction, matcher

  else if matcher instanceof Function
    matchReaction = (msg) -> msg instanceof ReactionMessage && matcher(msg)

  else
    callback = options
    options = matcher

  @listen matchReaction, options, callback


Response::react = () ->
  strings = [].slice.call(arguments)
  this.runWithMiddleware.apply(this, ['react', {plaintext: true}].concat(strings))

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
        @client.on 'error', (error) =>
          @robot.logger.error "The client encountered an error: #{error}"
        @client.on 'messageReactionAdd', (message, user)  => 
          @.message_reaction('reaction_added', message, user)
        @client.on 'messageReactionRemove', (message, user) => 
          @.message_reaction('reaction_removed', message, user)

        @client.login(@options.token).catch(@robot.logger.error)

     _map_user: (discord_user, channel_id) -> 
        user                      = @robot.brain.userForId discord_user.id
        user.room                 = channel_id
        user.name                 = discord_user.username
        user.discriminator        = discord_user.discriminator
        user.id                   = discord_user.id
        
        return user

      _format_incoming_message: (message) -> 
        @rooms[message.channel.id]?= message.channel
        text = message.cleanContent ? message.content
        if (message?.channel instanceof Discord.DMChannel)
          text = "#{@robot.name}: #{text}" if not text.match new RegExp( "^@?#{@robot.name}" )

        return text

      _has_permission: (channel, user) =>
        isText = channel != null && channel.type == 'text'
        permissions = isText && channel.permissionsFor(user)
        return if isText then (permissions != null && permissions.hasPermission("SEND_MESSAGES")) else channel.type != 'text'

      _send_success_callback: (adapter, channel, message) =>
        adapter.robot.logger.debug "SUCCESS! Message sent to: #{channel.id}"

      _send_fail_callback: (adapter, channel, message, error) =>
        adapter.robot.logger.debug "ERROR! Message not sent: #{message}\r\n#{err}"
        # check owner flag and prevent loops
        if(process.env.HUBOT_OWNER and channel.id != process.env.HUBOT_OWNER)
          sendMessage process.env.HUBOT_OWNER, "Couldn't send message to #{channel.name} (#{channel}) in #{channel.guild.name}, contact #{channel.guild.owner} to check permissions"

      _get_channel: (channelId) =>
        if @rooms[channelId]?
          channel = @rooms[channelId]
        else
          channels = @client.channels.filter (channel) -> channel.id == channelId
          if channels.first()?
            channel = channels.first()
          else
            channel = @client.users.get(channelId)
        return channel

     ready: =>
        @robot.logger.info "Logged in: #{@client.user.username}##{@client.user.discriminator}"
        @robot.name = @client.user.username
        @robot.logger.info "Robot Name: #{@robot.name}"
        @emit "connected"

        #post-connect actions
        @rooms[channel.id] = channel for channel in @client.channels
        @client.user.setActivity(currentlyPlaying)
          .then(@robot.logger.debug("Status set to #{currentlyPlaying}"))
          .catch(@robot.logger.error)

     message: (message) =>
        # ignore messages from myself
        return if message.author.id == @client.user.id

        user = @_map_user message.author, message.channel.id
        text = @_format_incoming_message(message)

        @robot.logger.debug text
        @receive new TextMessage( user, text, message.id )

     message_reaction: (reaction_type, message, user) => 
        # ignore reactions from myself
        return if user.id == @client.user.id

        reactor = @_map_user user, message.message.channel.id
        author = @_map_user message.message.author, message.message.channel.id
        text = @_format_incoming_message message.message

        text_message = new TextMessage(reactor, text, message.message.id)
        reaction = message._emoji.name
        if message._emoji.id?
          reaction += ":#{message._emoji.id}"
        @receive new ReactionMessage(reaction_type, reactor, reaction, author, 
          text_message, message.createdTimestamp)

     disconnected: =>
        @robot.logger.info "#{@robot.name} Disconnected, will auto reconnect soon..."

     send: (envelope, messages...) ->
        for message in messages
         @sendMessage envelope.room, message

     reply: (envelope, messages...) ->
        for message in messages
          @sendMessage envelope.room, "<@#{envelope.user.id}> #{message}"

     sendMessage: (channelId, message) ->

        #Padded blank space before messages to comply with https://github.com/meew0/discord-bot-best-practices
        zSWC              = "\u200B"
        message = zSWC+message

        channel = @._get_channel(channelId)
        that = @

        # check permissions
        if(channel and (!(channel instanceof TextChannel) or @_has_permission(channel, @robot?.client?.user)))
          channel.send(message, {split: true})
            .then (msg) ->
              that._send_success_callback that, channel, message, msg
            .catch (error) ->
              that._send_fail_callback that, channel, message, error
        else
          @._send_fail_callback @, channel, message, "Invalid Channel"

     react: (envelope, reactions...) ->
        robot = @robot
        channel = @._get_channel(envelope.room)
        that = @

        messageId =  if envelope.message instanceof ReactionMessage \
          then envelope.message.item.id
          else envelope.message.id

        if(channel and (!(channel instanceof TextChannel) or @_has_permission(channel, @robot?.client?.user)))
          for reaction in reactions
            @robot.logger.info reaction
            channel.fetchMessage(messageId)
              .then (message) -> 
                message.react(reaction)
                  .then (msg) ->
                    that._send_success_callback that, channel, message, msg
                  .catch (error) ->
                    that._send_fail_callback that, channel, message, error
              .catch (error) ->
                that._send_fail_callback that, channel, reaction, error
        else
          @._send_fail_callback @, channel, message, "Invalid Channel"


     channelDelete: (channel, client) ->
        roomId = channel.id
        user               = new User client.user.id
        user.room          = roomId
        user.name          = client.user.username
        user.discriminator = client.user.discriminator
        user.id            = client.user.id
        @robot.logger.info "#{user.name}##{user.discriminator} leaving #{roomId} after a channel delete"
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
        @robot.logger.info "#{user.name}##{user.discriminator} leaving #{roomId} after a guild delete"
        @receive new LeaveMessage(user, null, null)


exports.use = (robot) ->
    new DiscordBot robot
