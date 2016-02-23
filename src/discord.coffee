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

        @client = new Discord.Client
        @client.on 'ready', @.ready
        @client.on 'message', @.message

        @client.login @options.email, @options.password

     ready: =>
        @robot.logger.info 'Logged in: ' + @client.user.username
        @robot.name = @client.user.username.toLowerCase()
        @robot.logger.info "Robot Name: " + @robot.name
        @emit "connected"

     message: (message) =>

        # ignore messages from myself
        return if message.author.id == @client.user.id

        user = @robot.brain.userForId message.author.id
        user.room = message.channel.name
        rooms[message.channel.name] ?= message.channel

        text = message.cleanContent
        @robot.logger.debug text

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
