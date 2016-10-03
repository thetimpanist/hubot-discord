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
    {Robot, Adapter, EnterMessage, LeaveMessage, TopicMessage, TextMessage}  = require 'hubot'
catch
    prequire = require( 'parent-require' )
    {Robot, Adapter, EnterMessage, LeaveMessage, TopicMessage, TextMessage}  = prequire 'hubot'

Discord             = require "discord.js"

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

        @client = new Discord.Client {forceFetchUsers: true, autoReconnect: true, api_request_method: 'sequential'}
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
        
        if (message?.channel? instanceof Discord.DMChannel)
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
          robot.logger.error "Error sending: #{message}"
          robot.logger.error err
            
        #Padded blank space before messages to comply with https://github.com/meew0/discord-bot-best-practices
        zSWC              = "\u200B"
        message = zSWC+message
        
        robot = @robot
        sendChannelMessage = (channel, message) ->
          channel.sendMessage(message, {split: true})
            .then (msg) ->
              robot.logger.debug "SUCCESS! Message sent to: #{channel.id}"
            .catch errorHandle
                    
        sendUserMessage = (user, message) ->
          user.then (u) ->
            u.sendMessage(message, {split: true})
              .then (msg) ->
                robot.logger.debug "SUCCESS! Message sent to: #{user.id}"
              .catch errorHandle
              

        @robot.logger.debug "#{@robot.name}: Try to send message: \"#{message}\" to channel: #{channelId}"

        if @rooms[channelId]? # room is already known and cached
            sendChannelMessage @rooms[channelId], message
        else # unknown room, try to find it
            channels = @client.channels.filter (channel) -> channel.id == channelId
            if channels.first()?
                sendChannelMessage channels.first(), message
            else if @client.fetchUser(channelId)?
                sendUserMessage @client.fetchUser(channelId), message
            else
              @robot.logger.error "Unknown channel id: #{channelId}"
          
exports.use = (robot) ->
    new DiscordBot robot
