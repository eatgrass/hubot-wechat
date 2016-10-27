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

class WechatClient
    
    constructor: (@robot, conf)->

        @robot.logger.info 'initializing wechat client ...'
        @robot.logger.debug conf

        @events = new EventEmitter

        @property 'initialized',
            get: ->
                !!@syncKey

        @baseRequest = 
            Uin: conf.uin
            DeviceID: conf.deviceId
            Skey : conf.skey
            Sid : conf.sid

        @cookie = conf.cookie

        @wxApi = _thunkify wxApiMeta
        @pushApi = _thunkify pushApiMeta
        @fileApi = _thunkify fileApiMeta, json : false

        do @init
        do @syncCheck

        ## keep wechat client connection alive and listen new messages
        @on 'syncCheck', @syncCheck

        # register sync message handler
        @on 'sync', @_syncHandler

        
    init: ->
        
        co =>
            # init wechat api
            unless @initialized

                @robot.logger.info 'initializing wechat web api ...'

                _initRsp = yield @wxApi.post
                    uri : "/webwxinit"
                    body : 
                        BaseRequest : @baseRequest

                @robot.logger.debug "wechat api - init respond:\n #{_initRsp.BaseResponse}"

                unless _initRsp.BaseResponse.Ret is 0
                    @robot.logger.warning "failed to init wechat api with api server group"

                else
                    # update syncKey
                    @syncKey = init.SyncKey
                    @syncCheckCount = new Date().getTime()
                    @robot.wechatName = init.User.UserName
                    
                    # TODO init Chat Group 

                    @initTime = new Date()
    

    on: (event, args...) ->
        @events.on event, args...
        
    
    getContact : ->
        yield @wxApi.get
            uri : "/webwxgetcontact"

    sync: ->
        rsp = yield @wxApi.post
            uri : "/webwxsync"
            body :
                BaseRequest : baseRequest
                SyncKey : @syncKey
                rr : ~(new Date.getTime())

        # update sync key
        @syncKey = rsp.SyncKey
        rsp

    # listen incoming messages, fire 'sync' event based on the selector of
    syncCheck: ->

        co =>
            keys = _.map @syncKey.List, (key) -> "#{key.Key}_#{key.Val}"
            result = yield @pushApi.get
                uri : "/synccheck"
                qs :
                    r : new Date().getTime()
                    skey : @baseRequest.Skey
                    sid : @baseRequest.Sid
                    uin : @baseRequest.Uin
                    deviceid : @baseRequest.DeviceID
                    synckey : keys.join("|")
                    _ : @syncCheckCount++

            @robot.logger.debug "[syncCheck]: #{result}"
            result = JSON.parse(_.replace result, "window.synccheck=", "")
            unless result.retcode is 0 
                # failed to sync
                @robot.logger.error "sync check failed #{rejected}"
                @robot.logger.error "you might need to update your login settings and restart"
                do @robot.shutdown
            else
                @events.emit 'syncCheck'
                @events.emit 'sync', result.selector if result.selector > 0


    _syncHandler: (selector)->
        @robot.logger.info "sync message, select: #{selector}"
                

_thunkify = (meta, conf) ->
    _client = _.stubObject()
    _.forEach meta.methods, (method) ->
        _client[method] = (options) ->
            domain = url.parse meta.domain

            defaultOptions =
                baseUrl : meta.domain
                forever: true
                json: true
                headers :
                    Host: domain.host
                    Cookie : cookie

            configuredOption = _.defaultsDeep conf, defaultOptions
            options = _.defaultsDeep options, configuredOption

            (callback) ->
                request[method] options, (err, res, body) ->
                    unless err
                        callback null, body
                    else
                        callback err

    _client