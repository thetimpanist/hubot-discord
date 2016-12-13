# A [Hubot](https://github.com/github/hubot) adapter for [Discord](https://discordapp.com/)

You should report any issues or submit any pull requests to the
[Discord adapter](https://github.com/thetimpanist/hubot-discord) repository.

## Installation instructions

    npm install -g yo generator-hubot hubot-discord
    mkdir mybot
    cd mybot
    yo hubot

## Configuring variables on *nix
You will need to create a Discord account for your hubot and then invite the bot
to the channels you wish it to be present in

    % export HUBOT_DISCORD_TOKEN="..."
    % export HUBOT_MAX_MESSAGE_LENGTH="2000"

Environment Variable | Description | Example
--- | --- | ---
`HUBOT_DISCORD_TOKEN` | bot token for your oauth hubot | `MMMMMMMM`
`HUBOT_MAX_MESSAGE_LENGTH` | maximum message length to send at once | `2000`
`HUBOT_DISCORD_HELP_REPLY_IN_PRIVATE` |  whether or not to reply to help messages in private, defaults to false | `false`
`HUBOT_DISCORD_CARBON_TOKEN` | Carbonitex.net bot authentication | no example, it's a token
`HUBOT_DISCORD_BOTS_WEB_USER` |  bots.discord.pw user id for bot | same as above
`HUBOT_DISCORD_BOTS_WEB_TOKEN` |  bots.discord.pw auth token | same as above
`HUBOT_DISCORD_STATUS_MSG` | Status message to set for "currently playing game" | `/help for help`

The OAuth token can be created for an existing bot by [following this guide](https://github.com/DoNotSpamPls/repository/wiki/How-to-convert-your-bot-account-in-the-API).

## Launching your hubot
    
    cd /path/to/mybot
    ./bin/hubot -a discord

## Communicating with hubot
The default behavior of the bot is to respond to its account name in Discord

    botname help
