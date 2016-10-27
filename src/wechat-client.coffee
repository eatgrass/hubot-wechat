request = require 'request'
_ = require 'lodash'
url = require 'url'
co = require 'co'
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

module.exports = class WechatClient extends EventEmitter
    
    constructor: (@robot, conf)->

        self = this

        @robot.logger.info 'initializing wechat client ...'
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

        do @init

        
    init: ->
        @robot.logger.info 'initializing wechat web api ...'

        # start checking new message once the client initialized
        @on 'initialized', @syncCheck

        ## keep wechat client connection alive and listen new messages
        @on 'check', @syncCheck

        # register sync message handler
        @on 'message', @_syncHandler


        co =>
            # init wechat api
            unless @initialized

                _initRsp = yield @wxApi.post
                    uri : "/webwxinit"
                    body : 
                        BaseRequest : @baseRequest

                @robot.logger.info _initRsp.BaseResponse

                unless _initRsp.BaseResponse.Ret is 0
                    @robot.logger.warning "failed to init wechat api with api server group"

                else
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

    sync: ->
        

    # listen incoming messages, fire 'sync' event based on the selector of
    syncCheck: ->
        @robot.logger.info "sync checking"
        co =>
            keys = _.map @syncKey.List, (key) -> "#{key.Key}_#{key.Val}"
            querystring = 
                r : new Date().getTime()
                skey : @baseRequest.Skey
                sid : @baseRequest.Sid
                uin : @baseRequest.Uin
                deviceid : @baseRequest.DeviceID
                synckey : keys.join("|")
                _ : @syncCheckCount++
            
            result = yield @pushApi.get
                uri : "/synccheck"
                qs : querystring
                    

            result = _.replace result, "window", "this"
            @synccheck = eval(result)
            @robot.logger.info "[syncCheck] retcode: #{@synccheck.retcode}, selector: #{@synccheck.selector}"
            unless @synccheck.retcode is '0'
                # failed to sync
                @robot.logger.error "sync check failed #{rejected}"
                @robot.logger.error "you might need to update your login settings and restart"
                do @robot.shutdown
            else
                
                # selector 2 represents unread message
                if @synccheck.selector is '0'
                    @emit 'check'
                else
                    @emit 'message', @synccheck.selector
        .catch (e)->console.log e.stack


    _syncHandler: (selector)->
        @robot.logger.info "sync message, select #{selector}"

        thunk = @wxApi.post
            uri : "/webwxsync"
            body :
                BaseRequest : @baseRequest
                SyncKey : @syncKey
                rr : ~(new Date().getTime())

        thunk (err,rsp) =>
            console.log @
            @syncKey = rsp.SyncKey
            @robot.logger.info "sync finished"
            @emit 'check'
                

    _thunkify: (meta, conf) ->
        _client = _.stubObject()
        _.forEach meta.methods, (method) =>
            _client[method] = (options) =>
                domain = url.parse meta.domain

                defaultOptions =
                    baseUrl : meta.domain
                    forever: true
                    json: true
                    headers :
                        Host: domain.host
                        Cookie : @cookie

                configuredOption = _.defaultsDeep conf, defaultOptions
                options = _.defaultsDeep options, configuredOption

                (callback) ->
                    request[method] options, (err, res, body) ->
                        unless err
                            callback null, body
                        else
                            callback err

        _client