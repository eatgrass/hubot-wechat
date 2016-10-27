request = require 'request'
_ = require 'lodash'
url = require 'url'

wxClientMeta = {
    methods : ['get', 'post']
    domain : 'https://wx.qq.com/cgi-bin/mmwebwx-bin'
}

fileClientMeta = {
    methods : ['get', 'post']
    domain : 'https://file2.wx.qq.com/cgi-bin/mmwebwx-bin'
}

cookie = "pgv_pvi=4981005312; webwxuvid=7bb06db691d2993ec3f5acfbe1a6d41745f4c831819d7b844871ad250e07ec37ec3748bf9b1bda15f887e0575e752a7d; pgv_si=s9650208768; wxpluginkey=1477528921; MM_WX_NOTIFY_STATE=1; MM_WX_SOUND_STATE=1; wxuin=1590754113; wxsid=MImCCrf0BIKRoplT; wxloadtime=1477555655; mm_lang=zh_CN; webwx_data_ticket=gSeddP5T8IQeoX9XQQ9ET3pI"

_thunkify = (meta) ->
    _client = {}
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
                    
            options = _.defaultsDeep options, defaultOptions

            (callback) ->
                request[method] options, (err, res, body) ->
                    unless err
                        callback null, body
                    else
                        callback err

    _client


wxClient = _thunkify wxClientMeta
fileClient = _thunkify fileClientMeta


module.exports = (conf)->

    baseRequest = {"BaseRequest":{"Uin":"1590754113","Sid":"MImCCrf0BIKRoplT","Skey":"@crypt_612f6fff_14688f6d43a59a3e5db3de0d56750219","DeviceID":"e620951599534321"}}

    init : ->
        yield wxClient.post 
            uri : "/webwxinit"
            body : 
                BaseRequest : baseRequest


    getContact : ->
        yield wxClient.get
            uri : "/webwxgetcontact"

    sync : (syncKey)->
        yield wxClient.post
            uri : "/webwxsync"
            body :
                BaseRequest : baseRequest
                SyncKey : syncKey
                rr : ~(new Date.getTime())

    syncCheck: (syncKey)->
        yield wxClient.get
            uri : "/synccheck"
            qs : 
                r : new Date().getTime()
                skey : baseRequest.Skey
                sid : baseRequest.Sid
                uin : baseUrl.Uin