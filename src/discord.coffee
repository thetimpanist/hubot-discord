try
    {Robot, Adapter, EnterMessage, LeaveMessage, TopicMessage, TextMessage}  = require 'hubot'
catch
    prequire = require( 'parent-require' )
    {Robot, Adapter, EnterMessage, LeaveMessage, TopicMessage, TextMessage}  = prequire 'hubot'
Discord = require "discord.js"

rooms = {}

maxLength = parseInt(process.env.HUBOT_MAX_MESSAGE_LENGTH || 2000)

class DiscordBot extends Adapter
     constructor: (robot)->
        super
        @robot = robot
     
     run: ->
        @options =
            token: process.env.HUBOT_DISCORD_TOKEN
        # require oauth token type
        @options.token = "Bot " + @options.token if not @options.token.startsWith "Bot "

        @client = new Discord.Client {forceFetchUsers: true, autoReconnect: true}
        @client.on 'ready', @.ready
        @client.on 'message', @.message
        
        @client.loginWithToken @options.token, null, null, (err) ->
          @robot.logger.error err

     ready: =>
        @robot.logger.info 'Logged in: ' + @client.user.username
        @robot.name = @client.user.username.toLowerCase()
        @robot.logger.info "Robot Name: " + @robot.name
        @emit "connected"
        rooms[channel.id] = channel for channel in @client.channels

     message: (message) =>
        @robot.done = false
        # ignore messages from myself
        return if message.author.id == @client.user.id

        user = @robot.brain.userForId message.author.id
        user.room = message.channel.id
        user.name = message.author.name
        user.id = message.author.id
        rooms[message.channel.id] ?= message.channel

        text = message.cleanContent 
        if (message.channel instanceof Discord.PMChannel)
          text = "#{@robot.name}: #{text}" if not text.match new RegExp( "^@?#{@robot.name}" )

        @robot.logger.debug text
        @receive new TextMessage( user, text, message.id )
     
     chunkMessage: (msg) =>
        subMessages = []
        if(msg.length > maxLength)
          while msg.length > 0
            # Split message at last line break, if it exists
            chunk = msg.substring(0, maxLength)
            breakIndex = if chunk.lastIndexOf('\n') isnt -1 then chunk.lastIndexOf('\n') else maxLength
            subMessages.push msg.substring(0, breakIndex)
            # Skip char if split on line break
            breakIndex++ if breakIndex isnt maxLength
            msg = msg.substring(breakIndex, msg.length)
        else subMessages.push(msg)
        return subMessages

     send: (envelope, messages...) ->
        if messages.length > 0
          message = messages.shift()
          chunkedMessage = @chunkMessage message
          if chunkedMessage.length > 0
            chunk = chunkedMessage.shift()
            room = rooms[envelope.room]
            @client.sendMessage room, chunk, ((err) =>
              remainingMessages = chunkedMessage.concat messages
              if err then @robot.logger.error err
              @send envelope, remainingMessages...)
          
     reply: (envelope, messages...) ->
        # discord.js reply function looks for a 'sender' which doesn't 
        # exist in our envelope object
        user = envelope.user.name
        for msg in messages
          @client.sendMessage rooms[envelope.room], "#{user} #{msg}", (err) ->
                @robot.logger.error err


exports.use = (robot) ->
    new DiscordBot robot
