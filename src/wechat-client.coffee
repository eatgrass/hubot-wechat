request = require 'request'
_ = require 'lodash'
url = require 'url'
co = require 'co'
util = require 'util'
{EventEmitter} = require 'events'

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

testApiMeta = {
    methods : ['get']
    domain : "https://www.baidu.com"
}

module.exports = class WechatClient extends EventEmitter
    
    constructor: (@robot, conf)->

        self = this

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

        ## keep wechat client connection alive and listen new messages
        # @on 'check', @_syncCheck

        # # register sync message handler
        # @on 'sync', @_syncHandler


        co =>
            # init wechat api
            unless @initialized
                @robot.logger.info '[init] initializing wechat web api ...'

                _initRsp = yield @wxApi.post
                    uri : "/webwxinit"
                    body : 
                        BaseRequest : @baseRequest

                

                unless _initRsp.BaseResponse.Ret is 0
                    @robot.logger.warning "[init] failed to init wechat api with api server group"

                else
                    @robot.logger.info "[init] init successed, Ret: #{_initRsp.BaseResponse.Ret}"
                    # update syncKey
                    @syncKey = _initRsp.SyncKey
                    @syncCheckCount = new Date().getTime()
                    @robot.wechatName = _initRsp.User.UserName
                    
                    # TODO init Chat Group 

                    @initTime = new Date()
                    @emit "initialized"
        .catch (e)-> console.log e.stack

        
    
    getContact : ->
        yield @wxApi.get
            uri : "/webwxgetcontact"

    sync: =>
        rsp = yield @wxApi.post
            uri : "/webwxsync"
            body :
                BaseRequest : @baseRequest
                SyncKey : @syncKey
                rr : ~(new Date().getTime())
        console.log rsp
        rsp

    test: =>
        yield @testApi.get
            uri : "/"


    # listen incoming messages, fire 'sync' event based on the value of selector
    _syncCheck: =>
        @robot.logger.info "[syncCheck] sync checking"
        co =>
            keys = _.map @syncKey.List, (key) -> "#{key.Key}_#{key.Val}"
            check = yield  @pushApi.get
                uri : "/synccheck"
                qs : 
                    r : new Date().getTime()
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

                @robot.logger.info "[sync] sync"
                sync  = yield @wxApi.post
                    uri : "/webwxsync"
                    qs :
                        sid : @baseRequest.Sid
                        skey : @baseRequest.Skey
                    body :
                        BaseRequest : @baseRequest
                        SyncKey : @syncKey
                        rr : ~(new Date().getTime())

                # update sync key
                @syncKey = sync.SyncKey

                # process message
                @_notifyHubot sync, synccheck.selector
                    
        .then =>

            process.nextTick @_syncCheck
        
        .catch (e)->console.log e.code, e.connect            

    _notifyHubot: (sync, selector)=>
        console.log selector
        console.log sync

    _isGroup : (username)->
        _.startWith username, "@@"


    _updateContact: (contact)=>



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