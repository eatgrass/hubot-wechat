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
        @robot.logger.debug "Constructor: #{@robot.name}"

    send: (envelope, strings...) ->
        @robot.logger.info "Send"

        _.forEach strings, (content)=>
            @wechat.send envelope.user.id, content

    reply: (envelope, strings...) ->
        @robot.logger.info "Reply"

        _.forEach strings, (content)=>
            @wechat.send envelope.user.id, content
    run: ->
        @wechat.init()



exports.use = (robot) ->
    new WechatRobot robot