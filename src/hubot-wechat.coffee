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

        cookie = "webwxuvid=7bb06db691d2993ec3f5acfbe1a6d417a7afac6c593268bc84d9fd1b9bf56691450c8f206f82e6843bdd34a4cf7cf1d1; pgv_pvi=4412844032; tvfe_boss_uuid=5c5c34ed0123b90e; pgv_pvid=5164137956; pgv_si=s9739249664; wxloadtime=1477917347_expired; wxpluginkey=1477908541; wxuin=1753980132; wxsid=y7YCwjrhj5NL19ix; webwx_data_ticket=gSelgg1CFcISVwaYBs+oxXoE; mm_lang=zh_CN; MM_WX_NOTIFY_STATE=1; MM_WX_SOUND_STATE=1; webwxuvid=7bb06db691d2993ec3f5acfbe1a6d417a7afac6c593268bc84d9fd1b9bf56691450c8f206f82e6843bdd34a4cf7cf1d1; pgv_pvi=4412844032; tvfe_boss_uuid=5c5c34ed0123b90e; pgv_pvid=5164137956; pgv_si=s9739249664; wxpluginkey=1477908541; MM_WX_NOTIFY_STATE=1; MM_WX_SOUND_STATE=1; wxuin=1753980132; wxsid=TCR/XcKPVT001XpA; wxloadtime=1477921807; mm_lang=zh_CN; webwx_data_ticket=gScgyGrmUwdSr/8ZOeBnkNMG"

        b ={"Uin":"1753980132","Sid":"TCR/XcKPVT001XpA","Skey":"@crypt_21572829_22f1f1af38aab15b4dba1cf4e575e15d","DeviceID":"e937390160573044"}
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
        # @robot.logger.info "Run"

        @wechat.init()
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