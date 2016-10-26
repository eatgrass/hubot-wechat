request = require 'request'
_ = require 'lodash'
url = require 'url'

wxClientMeta = {
    methods : ['get', 'post']
    domain : 'http://wx2.qq.com/cgi-bin/mmwebwx-bin'
}

fileClientMeta = {
    methods : ['get', 'post']
    domain : 'https://file2.wx.qq.com/cgi-bin/mmwebwx-bin'
}

_thunkify = (meta) ->
    _client = {}
    _.forEach meta.methods, (method) ->
        _client[method] = (options) ->

            defaultOptions =
                baseUrl : meta.domain
                forever: true
                headers :
                    Host:"wx2.qq.com, file2.wx.qq.com"
                    
            options = _.defaultsDeep options, defaultOptions

            (callback) ->
                request.cookie process.env.HUBOT_WX_COOKIE or ""
                request.get options, (err, res, body) ->
                    unless err
                        callback null, body
                    else
                        callback err

    _client


wxClient = _thunkify wxClientMeta
fileClient = _thunkify fileClientMeta


module.exports = (loginInfo)->
    getContact : ->
        yield wxClient.get {uri : "/webwxgetcontact"}