request = require 'request'
_ = require 'lodash'
url = require 'url'
co = require 'co'
util = require 'util'
{EventEmitter} = require 'events'
try
    {TextMessage,User} = require 'hubot'
catch
    prequire = require('parent-require')
    {TextMessage,User} = prequire 'hubot'

# TODO Configurable

wxApiMeta = {
    methods : ['get', 'post']
    domain : 'https://wx.qq.com/cgi-bin/mmwebwx-bin'
}

fileApiMeta = {
    methods : ['get', 'post']
    domain : 'https://file2.wx.qq.com/cgi-bin/mmwebwx-bin'
}

pushApiMeta = {
    methods : ['get', 'post']
    domain : 'https://webpush.wx.qq.com/cgi-bin/mmwebwx-bin'
}

master = 'uniqhj'

module.exports = class WechatClient extends EventEmitter
    
    constructor: (@adapter, conf)->

        @robot = @adapter.robot

        @robot.logger.info '[wechat client] initializing wechat client ...'
        @robot.logger.info conf

        @baseRequest = 
            Uin: conf.uin
            DeviceID: conf.deviceId
            Skey : conf.skey
            Sid : conf.sid

        @cookie = conf.cookie

        @wxApi = @_thunkify wxApiMeta
        @pushApi = @_thunkify pushApiMeta, json : false
        @fileApi = @_thunkify fileApiMeta, json : false
        
    init: ->

        # start checking new message once the client initialized
        @once 'initialized', @_syncCheck

        co =>
            # init wechat api
            unless @initialized
                @robot.logger.info '[init] initializing wechat web api ...'

                _initRsp = yield @wxApi.post
                    uri : "/webwxinit"
                    body : 
                        BaseRequest : @baseRequest

                unless _initRsp.BaseResponse.Ret is 0
                    @robot.logger.warning "[init] failed to init wechat api"
                    do @adapter.robot.shutdown
                else
                    @robot.logger.info "[init] init successed, Ret: #{_initRsp.BaseResponse.Ret}"

                    # save syncKey
                    @syncKey = _initRsp.SyncKey
                    @syncCheckCount = Date.now()
                    
                    # own user info
                    @robot.me = _initRsp.User

                    # save contacts
                    contactRsp = yield @getContact()
                    @robot.contacts = contactRsp.MemberList

                    # save master info
                    @robot.master = _.find contactRsp, (u) -> 
                        (u.Alias is master) or (u.NickName is master) or (u.UserName is master)

                    # TODO group contacts
                    
                    @initTime = new Date()
                    @emit "initialized"
                    @adapter.emit "connected"
        .catch (e)-> console.log e.stack

        
    
    getContact : =>
        yield @wxApi.get
            uri : "/webwxgetcontact"
            qs :
                seq : 0
                r : Date.now()
                skey : @baseRequest.Skey

    send: (to, content)=>
        co =>
            msgId = (Date.now() + Math.random().toFixed(3)).replace '.', ''

            yield @wxApi.post
                uri : "/webwxsendmsg"
                body :
                    BaseRequest : @baseRequest
                    Msg :
                        Type : 1
                        Content : content
                        ClientMsgId : msgId
                        LocalID : msgId
                        FromUserName : @robot.me.UserName
                        ToUserName : to
                    Scene : 0
        .catch (e)=> console.log e.stack

    # listen incoming messages, fire 'sync' event based on the value of selector
    _syncCheck: =>
        @robot.logger.info "[syncCheck] sync checking"
        co =>
            keys = _.map @syncKey.List, (key) -> "#{key.Key}_#{key.Val}"
            check = yield  @pushApi.get
                uri : "/synccheck"
                qs : 
                    r : Date.now()
                    skey : @baseRequest.Skey
                    sid : @baseRequest.Sid
                    uin : @baseRequest.Uin
                    deviceid : @baseRequest.DeviceID
                    synckey : keys.join("|")
                    _ : @syncCheckCount++

            synccheck = eval(_.replace check, "window.", "")

            unless synccheck.retcode is '0'
                @robot.logger.error "[syncCheck] sync check failed ,request rejected"
                do @robot.shutdown

            unless synccheck.selector is '0'

                @robot.logger.info "[sync] sync message"
                sync  = yield @wxApi.post
                    uri : "/webwxsync"
                    qs :
                        sid : @baseRequest.Sid
                        skey : @baseRequest.Skey
                    body :
                        BaseRequest : @baseRequest
                        SyncKey : @syncKey
                        rr : ~Date.now()

                # update sync key
                @syncKey = sync.SyncKey

                # process message
                @_resolveMessage sync, synccheck.selector
                    
        .then =>

            process.nextTick @_syncCheck
        
        .catch (e)->console.log e.stack


    _resolveMessage: (sync, selector) =>
        _.forEach sync.AddMsgList, @_notifyHubot
    
    _notifyHubot: (message) =>
        console.log message
        # group message
        if @_isGroup message.FromUserName 
            [..., from = 'anonymous', content] = /([@0-9a-z]+):<br\/>([\s\S]*)/.exec message.Content

            group = message.FromUserName
            groupName = @contact[groupUser]
            user = new User from, {ChatRoom: group}
        # normal message from user
        else
            from = message.FromUserName
            content = message.Content
            user = new User from

        @robot.logger.info "[incoming message] group: #{group}"
        @robot.logger.info "[incoming message] from: #{from}"
        @robot.logger.info "[incoming message] content: #{content}"

        # console.log user
        @robot.receive new TextMessage user, content, null

    _isGroup : (username)->
        _.startsWith username, "@@"


    _thunkify: (meta, conf) ->
        _client = _.stubObject()
        _.forEach meta.methods, (method) =>
            _client[method] = (options) =>
                domain = url.parse meta.domain

                defaultOptions =
                    baseUrl : meta.domain
                    forever: true
                    json: true
                    pool: 
                        maxSockets: Infinity
                    headers :
                        "Host": domain.host
                        "Cookie": @cookie
                        "Cache-Control": "no-cache"

                configuredOption = _.defaultsDeep conf, defaultOptions
                options = _.defaultsDeep options, configuredOption

                (callback) =>
                    r = request.defaults options
                    r[method] options, (err, res, body) =>
                        unless err
                            callback null, body
                        else
                            callback err

        _client