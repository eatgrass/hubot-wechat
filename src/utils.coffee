{parseString} = require 'xml2js'


exports.unescapeHTML = unescapeHTML = (str) ->

    chars = 
        '&#39;': '\''
        '&amp;': '&'
        '&gt;': '>'
        '&lt;': '<'
        '&quot;': '"'

    unescaped = ''

    unless str == null

        keys = Object.keys chars
        .join '|'

        re = new RegExp "(#{keys})", 'g'

        unescaped =  String str
        .replace re, (match) ->
            chars[match]

    unescaped
        

    
exports.parseXml = (str) ->

    unescaped = unescapeHTML str

    (callback)->
        parseString unescaped, callback

