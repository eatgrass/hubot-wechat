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

cookie = "MM_WX_NOTIFY_STATE=1; MM_WX_SOUND_STATE=1; pgv_pvi=4981005312; pgv_si=s119224320; wxuin=1590754113; wxsid=3cUbUL/U8zjZ4HSz; wxloadtime=1477487785; mm_lang=zh_CN; webwx_data_ticket=gScenMXoWuDYWmmTDuEc32mk; webwxuvid=7bb06db691d2993ec3f5acfbe1a6d41745f4c831819d7b844871ad250e07ec37ec3748bf9b1bda15f887e0575e752a7d"

_thunkify = (meta) ->
    _client = {}
    _.forEach meta.methods, (method) ->
        _client[method] = (options) ->

            domain = url.parse meta.domain
            # console.log domain

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

    baseRequest = 
        Uin :"1590754113"
        Sid:"3cUbUL/U8zjZ4HSz"
        Skey:"@crypt_612f6fff_5f84b84993850aa9fa17793c4dba4e7d"
        DeviceID:"e568153623706182"

    init : ->
        yield wxClient.post 
            uri : "/webwxinit"
            body : 
                BaseRequest : baseRequest


    getContact : ->
        yield wxClient.get {uri : "/webwxgetcontact"}