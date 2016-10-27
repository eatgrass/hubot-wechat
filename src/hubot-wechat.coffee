try
    {Robot,Adapter,TextMessage,User} = require 'hubot'
catch
    prequire = require('parent-require')
    {Robot,Adapter,TextMessage,User} = prequire 'hubot'

co = require 'co'
WechatClient = require './wechat-client'


class Sample extends Adapter

    constructor: ->
        super

        cookie = "pgv_pvi=4981005312; webwxuvid=7bb06db691d2993ec3f5acfbe1a6d41745f4c831819d7b844871ad250e07ec37ec3748bf9b1bda15f887e0575e752a7d; pgv_si=s9650208768; wxpluginkey=1477561321; MM_WX_NOTIFY_STATE=1; MM_WX_SOUND_STATE=1; wxuin=1590754113; wxsid=ITC76p1Kw6eHJlWC; wxloadtime=1477576598; mm_lang=zh_CN; webwx_data_ticket=gSd4ql0lgctOpu7WLbblLrvQ"

        b ={"Uin":"1590754113","Sid":"ITC76p1Kw6eHJlWC","Skey":"@crypt_612f6fff_73711bc3551dd3ae8f1a8ea8aa44107a","DeviceID":"e930504458747442"}
        
        conf =
            uin : b.Uin
            sid : b.Sid
            skey : b.Skey
            deviceId : b.DeviceID
            cookie : cookie

        @wechat = new WechatClient @robot, conf
        @robot.logger.info "Constructor"

    send: (envelope, strings...) ->
        @robot.logger.info "Send"

    reply: (envelope, strings...) ->
        @robot.logger.info "Reply"

    run: ->
        @robot.logger.info "Run"
        # do @wechat.syncCheck
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
        # setInterval =>
        #     co =>
        #         yield @test()
        # ,5000

    test : =>
        # res = yield @wechat.init()
        # @robot.logger.info res.SyncKey




exports.use = (robot) ->
    new Sample robot