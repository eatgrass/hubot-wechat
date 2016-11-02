try
    {Robot,Adapter,TextMessage,User} = require 'hubot'
catch
    prequire = require('parent-require')
    {Robot,Adapter,TextMessage,User} = prequire 'hubot'

co = require 'co'
_ = require 'lodash'
WechatClient = require './wechat-client'

class WechatRobot extends Adapter

    constructor: ->
        super
        
        @wechat = new WechatClient @
        @robot.logger.info "Constructor"

    send: (envelope, strings...) ->
        @robot.logger.info "Send"

        # send to group

        # send to user
        _.forEach strings, (content)=>
            @wechat.send envelope.user.id, content
        # console.log envelope.user.id

    reply: (envelope, strings...) ->
        @robot.logger.info "Reply"

        console.log envelope

    run: ->
        @wechat.init()



exports.use = (robot) ->
    new WechatRobot robot