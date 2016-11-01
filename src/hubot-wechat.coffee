try
    {Robot,Adapter,TextMessage,User} = require 'hubot'
catch
    prequire = require('parent-require')
    {Robot,Adapter,TextMessage,User} = prequire 'hubot'

co = require 'co'
WechatClient = require './wechat-client'
_ = require 'lodash'


class WechatRobot extends Adapter

    constructor: ->
        super

        cookie = "webwxuvid=7bb06db691d2993ec3f5acfbe1a6d417a7afac6c593268bc84d9fd1b9bf56691450c8f206f82e6843bdd34a4cf7cf1d1; pgv_pvi=4412844032; tvfe_boss_uuid=5c5c34ed0123b90e; pgv_pvid=5164137956; webwx_auth_ticket=CIsBENW/g9sJGoABE520f3E70cuxcTzYnEyJ0vh3sPj2XJt4CLR1ryXy4QYSwVak2jgHzxbGo1ucKsYX03WrZWj0N2Ed2ZDvpBeD/gehSz+RDGQonCm0CXQZAs/menDd2dG715gkvYqoQwYBxx/UJRnqy8yIjY71S3vgqt9rhU7C14q9aouDZu2G0Ss=; wxloadtime=1477977386_expired; wxpluginkey=1477960742; wxuin=1753980132; wxsid=1Gcv6mOXgIlqSe5L; webwx_data_ticket=gSfpk5rs0UuXyUHQxoNdDS+s; mm_lang=zh_CN; MM_WX_NOTIFY_STATE=1; MM_WX_SOUND_STATE=1; pgv_si=s540050432"

        b ={"Uin":"1753980132","Sid":"OxwrZCe98ue9OcM6","Skey":"@crypt_21572829_ab01e8913b785113782ed0cf8f98a938","DeviceID":"e298990023890308"}
        conf =
            uin : b.Uin
            sid : b.Sid
            skey : b.Skey
            deviceId : b.DeviceID
            cookie : cookie

        @wechat = new WechatClient @, conf
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