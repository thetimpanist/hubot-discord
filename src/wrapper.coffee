# This script contains wrappers for many discord.js objects.  The raw objects
# are overly large and contain circular object references that don't play well
# with hubot brain.

class DiscordRawMessage
    # Represents a message from discord.js

    constructor: ( message )->
        @id = message.id
        @content = message.cleanContent
        @user = new DiscordRawUser message.author 
        @channel = new DiscordRawChannel message.channel
        @mentions = ( new DiscordRawUser user for user in message.mentions )
        
        
class DiscordRawUser
    # Represents a user from discord.js
    
    constructor: ( user )->
        @id = user.id
        @username = user.username

class DiscordRawChannel
    # Represents a channel from discord.js
    
    constructor: ( channel )->
        @id = channel.id
        @name = channel.name
        @server = new DiscordRawServer channel.server

class DiscordRawServer
    # Represents a user from discord.js
    
    constructor: ( server )->
        @id = server.id
        @name = server.name

module.exports = {
    DiscordRawMessage,
    DiscordRawUser,
    DiscordRawChannel,
    DiscordRawServer
}
