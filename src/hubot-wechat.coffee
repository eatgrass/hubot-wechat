try
    {Robot,Adapter,TextMessage,User} = require 'hubot'
catch
    prequire = require('parent-require')
    {Robot,Adapter,TextMessage,User} = prequire 'hubot'

co = require 'co'
wechatApi = require './wechat-api'


class Sample extends Adapter

    constructor: ->
        super

        loginInfo =
            Uin : process.env.HUBOT_WX_UIN
            Sid : process.env.HUBOT_WX_SID
            Skey : process.env.HUBOT_WX_SKEY
            DeviceID : process.env.HUBOT_WX_DEVICE_ID
            cookie : process.env.HUBOT_WX_COOKIE

        @wechat = do wechatApi
        @robot.logger.info "Constructor"

    send: (envelope, strings...) ->
        @robot.logger.info "Send"

    reply: (envelope, strings...) ->
        @robot.logger.info "Reply"

    run: ->
        @robot.logger.info "Run"
        do @daemon
        # co @test
        # .then(
        #     =>
        #         @emit "connected"
        #         user = new User 1001, name: 'Sample User'
        #         message = new TextMessage user, 'Some Sample Message', 'MSG-001'
        #         @robot.receive message
        #     =>
        #         @robot.logger.warn "rejected"
        # ).catch (e)=>
        #     @robot.logger.error e

    daemon : ->
        setInterval =>
            co =>
                yield @test()
        ,5000

    test : =>
        res = yield @wechat.init()
        @robot.logger.info res.SyncKey




exports.use = (robot) ->
    new Sample robot