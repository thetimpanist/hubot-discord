try
    {Robot, Adapter, EnterMessage, LeaveMessage, TopicMessage, TextMessage}  = require 'hubot'
catch
    prequire = require( 'parent-require' )
    {Robot, Adapter, EnterMessage, LeaveMessage, TopicMessage, TextMessage}  = prequire 'hubot'
Discord = require "discord.js"

rooms = {}

class DiscordBot extends Adapter
    constructor: (robot)->
        super
        @robot = robot

     run: ->
        @options =
            email: process.env.HUBOT_DISCORD_EMAIL,
            password: process.env.HUBOT_DISCORD_PASSWORD
            playing_game: process.env.HUBOT_DISCORD_PLAYING_GAME

        @client = new Discord.Client
        @client.on 'ready', @.ready
        @client.on 'message', @.message

        @client.login @options.email, @options.password

     ready: =>
        @robot.logger.info 'Logged in: ' + @client.user.username
        @robot.name = @client.user.username.toLowerCase()
        @robot.logger.info "Robot Name: " + @robot.name

        # set the bot's 'Playing Game' option
        if (@options.playing_game)
            @client.setPlayingGame(@options.playing_game)
            @robot.logger.info "Robot Game: " + @options.playing_game

        @emit "connected"

     message: (message) =>

        # ignore messages from myself
        return if message.author.id == @client.user.id

        user = @robot.brain.userForId message.author.id
        user.room = message.channel.name
        user.name = message.author.name
        rooms[message.channel.name] ?= message.channel

        text = message.cleanContent
        @robot.logger.debug text

        if (message.channel instanceof Discord.PMChannel)
          text = "#{@robot.name}: #{text}"

        @receive new TextMessage( user, text, message.id )

     send: (envelope, messages...) ->
        for msg in messages
            @client.sendMessage rooms[envelope.room], msg

     reply: (envelope, messages...) ->

        # discord.js reply function looks for a 'sender' which doesn't 
        # exist in our envelope object

        user = envelope.user.name
        for msg in messages
            @client.sendMessage rooms[envelope.room], "#{user} #{msg}" 
        
        
exports.use = (robot) ->
    new DiscordBot robot
