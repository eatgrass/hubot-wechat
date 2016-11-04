# Hubot Wechat Adapter [![Build Status](https://travis-ci.org/eatgrass/hubot-wechat.svg?branch=develop)](https://travis-ci.org/eatgrass/hubot-wechat)

[![NPM](https://nodei.co/npm/hubot-wechat2.png?compact=true)](https://nodei.co/npm/hubot-wechat2/)

## Quickstart:

### Existing install

1. Install wechat adapter:

        % cd myhubot
        % npm install hubot-wechat2 --save

1. You will need to set configuration variables in your environment for wechat account

    indicate your hubot to use `wechat2` as adapter, you can also run `bin/hubot -a wechat2`

        HUBOT_ADAPTER=wechat2
        
    Below properties are required, you can get these properties by capturing `webwxinit` request in your browser
    
        HUBOT_WX_COOKIE
        HUBOT_WX_UIN
        HUBOT_WX_SID
        HUBOT_WX_SKEY
        HUBOT_WX_DEVICE_ID

1. Run your robot with
    
        % myhubot/bin/hubot -a wechat2
        
### Start with PM2

1. install pm2 `npm install pm2 -g`

1. copy the `process.json`

1. specify your configuration in your `process.json`

1. start with `pm2 startOrRestart process.json`
                
## Options

Environment Variable | Default | Description
:---- | :----| :----
HUBOT_WX_ACCEPT_FRIEND | false | Auto accept frient request
HUBOT_WX_IGNORE_GROUP  | false | Ignore message from group
    
