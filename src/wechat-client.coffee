try
    {TextMessage,User} = require 'hubot'
catch
    prequire = require('parent-require')
    {TextMessage,User} = prequire 'hubot'

{EventEmitter} = require 'events'

request = require 'request'
_ = require 'lodash'
url = require 'url'
co = require 'co'
util = require 'util'
yaml = require('js-yaml')
fs   = require('fs')
path = require 'path'
utils = require './utils'

module.exports = class WechatClient extends EventEmitter
    
    constructor: (@adapter, conf)->

        @robot = @adapter.robot
        @serverGroups = []

        @baseRequest = 
            Uin: process.env.HUBOT_WX_UIN
            DeviceID: process.env.HUBOT_WX_DEVICE_ID
            Skey: process.env.HUBOT_WX_SKEY 
            Sid: process.env.HUBOT_WX_SID 

        @cookie = process.env.HUBOT_WX_COOKIE

        @acceptFriend = process.env.HUBOT_WX_ACCEPT_FRIEND or false
        @ignoreGroupMessage = process.env.HUBOT_WX_IGNORE_GROUP or false

        profilePath = path.join __dirname, '..', 'server-profile.yml'
        config = fs.readFileSync profilePath , 'utf8'
        yaml.safeLoadAll config, (profile)=>
            server =
                wxApi : @_thunkify profile['api']
                pushApi : @_thunkify profile['push'], json : false
                fileApi : @_thunkify profile['file'], json : false

            @serverGroups.push server

        @once 'initialized', @_syncCheck

        
    init: ->

        f_resolve = _.map @serverGroups, (server, i) =>
            =>
                unless @initialized
                    @robot.logger.info "[init] initializing wechat web api with server group #{i + 1}"

                    @wxApi = server.wxApi
                    @pushApi = server.pushApi
                    @fileApi = server.fileApi

                    _initRsp = yield @wxApi.post
                        uri : "/webwxinit"
                        body : 
                            BaseRequest : @baseRequest

                    unless _initRsp.BaseResponse.Ret is 0
                        @robot.logger.warning "[init] server group #{i} failed, #{@serverGroups.length - i - 1} group remaining"

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
                            master = process.env.HUBOT_WX_MASTER
                            (u.Alias is master) or (u.NickName is master) or (u.UserName is master)

                        # TODO group contacts
                        @initialized = true
                        @initTime = new Date()
                        
                        @emit "initialized"
                        @adapter.emit "connected"


        co =>
            for f in f_resolve
                yield f()
        .catch (e)-> 
            console.log e.stack

        
    
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
        
        .catch (e)->
            if _.includes ['ECONNRESET','ETIMEDOUT'], e.code
                process.nextTick @_syncCheck
            console.log e.stack


    _resolveMessage: (sync, selector) =>

        @robot.logger.debug sync


        # FIXME
        # 1 update [Profile]
        # 4 update contacts [DelContactList, ModeContactList]

        # 2 new message [AddMsgList]
        f_message = _.map sync.AddMsgList, (message)=>
            =>
                from = message.FromUserName
                content = message.Content

                # session opened
                if message.MsgType is 51
                    xmlContent = yield utils.parseXml content

                # normal message
                if message.MsgType is 1

                    # message from group
                    if @_isGroup message.FromUserName
                        [..., groupUser = 'anonymous', content] = /([@0-9a-z]+):<br\/>([\s\S]*)/.exec message.Content

                    @_notifyHubot from, content, groupUser, message.MsgId

                # system notification 
                if message.MsgType is 10000
                    @robot.logger.info content

                # friend request
                if message.MsgType is 37 and from is 'fmessage' 
                    if @acceptFriend
                        @robot.logger.debug "verify friend: "
                        @robot.logger.debug "#{message.RecommendInfo}"
                        rsp = yield @verifyFriend 
                            Value : message.RecommendInfo.UserName
                            VerifyUserTicket : message.RecommendInfo.Ticket
                        @robot.logger.debug rsp
        co =>
            yield f_message
        .catch (e)-> console.log e.stack
                
    verifyFriend : (user)=>

        yield @wxApi.post
            uri : "/webwxverifyuser"
            qs :
                r: Date.now()
            body:
                BaseRequest: @baseRequest
                Opcode: 3
                SceneList:[33]
                SceneListCount: 1
                VerifyContent: ""
                VerifyUserList: [user]
                VerifyUserListSize: 1
                skey: @baseRequest.Skey
            
    _notifyHubot: (from, content, groupUser, MsgId) =>
        user = new User from, groupUser : groupUser
        unless (@_isGroup from and @ignoreGroupMessage)
            @robot.receive new TextMessage user, content, MsgId
                

    _isGroup : (username)->
        _.startsWith username, "@@"


    _thunkify: (meta, conf) ->
        _client = _.stubObject()
        _.forEach ['get','post'], (method) =>
            _client[method] = (options) =>
                domain = url.parse meta.domain

                defaultOptions =
                    timeout : 32000
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