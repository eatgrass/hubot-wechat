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


    # listen incoming messages, fire 'sync' event based on the selector of
    _syncCheck: =>
        @robot.logger.info "[syncCheck] sync checking"
        co =>
            keys = _.map @syncKey.List, (key) -> "#{key.Key}_#{key.Val}"
            console.log "sync key"                
            console.log @syncKey
            syncCheck = 
                check :  @pushApi.get
                    uri : "/synccheck"
                    qs : 
                        r : new Date().getTime()
                        skey : @baseRequest.Skey
                        sid : @baseRequest.Sid
                        uin : @baseRequest.Uin
                        deviceid : @baseRequest.DeviceID
                        synckey : keys.join("|")
                        _ : @syncCheckCount++

                sync : @wxApi.post
                    uri : "/webwxsync"
                    qs :
                        sid : @baseRequest.Sid
                        skey : @baseRequest.Skey
                    body :
                        BaseRequest : @baseRequest
                        SyncKey : @syncKey
                        rr : ~(new Date().getTime())
                    

            # result = _.replace result, "window.", ""
            # check = eval(result)
            # unless check.retcode is '0'
            #     @robot.logger.error "[syncCheck] sync check failed ,request rejected"
            #     do @robot.shutdown
            
            # console.log "selector:",check.selector

            # unless check.selector is '0'
            # setTimeout(
            #     => 
            #         console.log (new Date())
            #     ,1500000
            # )
            # yield @sync()
            # @robot.logger.info "[syncCheck] retcode: #{@synccheck.retcode}, selector: #{@synccheck.selector}"
            # unless @synccheck.retcode is '0'
            #     # failed to sync
            #     @robot.logger.error "[syncCheck] sync check failed ,request rejected"
            #     @robot.logger.error "[syncCheck] you might need to update your login settings and restart"
            #     do @robot.shutdown
            # else

            #     unless @synccheck.selector is '0'
            #         @robot.logger.info "[sync] sync"
                        
            #         syncRsp = yield @test()
                    
            #         # @syncKey = syncRsp.SyncKey
            #         console.log syncRsp
            #         @robot.logger.info "[sync] sync finished"
                
            #     process.nextTick @_syncCheck
            yield sleep(5000)
            yield syncCheck
        .then (check)=>
            console.log "res sync key"
            console.log check.sync?.SyncKey
            @syncKey = check.sync.SyncKey if check.sync
            # unless check.retcode is '0'
            #     @robot.logger.error "[syncCheck] sync check failed ,request rejected"
            #     do @robot.shutdown
            # else
            #     yield @sync()
            # @synckKey = check.SyncKey if check?.SyncKey
            # console.log check?.SyncKey
            process.nextTick @_syncCheck
        # .then (selector)=>
        #     console.log selector
        #     # unless selector is '0'
        #     #     syncRsp = yield @sync()
        #     #     console.log syncRsp
        # .then =>
        #     console.log ('done')
        #     # process.nextTick @_syncCheck

        .catch (e)->console.log e.code, e.connect


    _syncHandler: =>

        @robot.logger.info "[sync] sync message"
        # body =
            

        # console.log(util.inspect(body))
        # console.log(util.inspect(body.SyncKey.List))
        # thunk = @wxApi.post
            
                

        # thunk (err,rsp) =>

        #     # console.log this

        #     unless err
                
        #     else
        #         console.log err.stack
        


    _resolveMessage: (body) =>

        # @robot.logger.info body

        if body.AddMsgCount > 0
            _.forEach body.AddMsgList, (message) =>
                @_notifyMessage message

        # if body.ModContactCount != 0
        #     _.forEach body.ModContactList, (contact) =>
        #         self._updateContact self, contact


    _notifyMessage: (message)=>
        # self.robot.logger.info message

        # content = message.Content

        # if @_isGroup message.FromUserName
        #     rc = (/([@0-9a-z]+):<br\/>([\s\S]*)/).exec content
        #     if rc then [..., from , content] = rc else from = 'anonymous'
        #     groupName = message.FromUserName
        #     groupNickname = @groupContacts[groupUserName]

        # else
        #     from = message.FromUserName
        #     content = message.Content

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
                        Host: domain.host
                        Cookie : @cookie
                        "Cache-Control":"no-cache"
                        Connection: "keep-alive"
                        Pragma:"no-cache"
                        Referer:"https://wx.qq.com/"

                configuredOption = _.defaultsDeep conf, defaultOptions
                options = _.defaultsDeep options, configuredOption

                (callback) =>
                    r = request.defaults options
                    r[method] options, (err, res, body) =>
                        unless err
                            callback null, body
                        # else if err.code is 'ECONNRESET'
                        #     callback null, null
                        else
                            console.error err
                            callback err

        _client


sleep = (ms)=>
    (cb) =>
        setTimeout(cb,ms)