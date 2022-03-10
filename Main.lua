local http = require "http"
local https = require "https"
local json = require "json"

local port = 3000
local LETTER_TYPE = {
    empty = 1,
    completeHangeul = 2,
    notCompleteHangeul = 3,
    englishUpper = 4,
    englishLower = 5,
    number = 6,
    specialLetter = 7,
    unknown = 8
}
data = {}

-- utils
function utf8.sub(s,i,j)
    i=utf8.offset(s,i)
    j=utf8.offset(s,j+1)-1
    return string.sub(s,i,j)
end
local decodeURI
do
    local char, gsub, tonumber = string.char, string.gsub, tonumber
    local function _(hex) return char(tonumber(hex, 16)) end

    function decodeURI(s)
        s = gsub(s, '%%(%x%x)', _)
        return s
    end
end
local function isInRange(value, range)
    return value >= range.start and value <= range["end"]
end
local function hasValue (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

-- fetch dataset
local req = https.request("https://raw.githubusercontent.com/numgle/dataset/main/src/data.json", function(res)
    local body = ""
    res:on("data", function(chunk)
        body = body .. chunk
    end)
    res:on("end", function()
        data = json.parse(body)
    end)
end)
req:on("error", function(err)
    print("Error: " .. err)
end)
req:done()

-- main
local function getLetterType(charCode)
    if charCode ~= charCode or charCode == 13 or charCode == 10 or charCode == 32 then
        return LETTER_TYPE.empty
    elseif isInRange(charCode, data.range.completeHangul) then
        return LETTER_TYPE.completeHangeul
    elseif isInRange(charCode, data.range.notCompleteHangul) then
        return LETTER_TYPE.notCompleteHangeul
    elseif isInRange(charCode, data.range.uppercase) then
        return LETTER_TYPE.englishUpper
    elseif isInRange(charCode, data.range.lowercase) then
        return LETTER_TYPE.englishLower
    elseif isInRange(charCode, data.range.number) then
        return LETTER_TYPE.number
    elseif hasValue(data.range.special, charCode) then
        return LETTER_TYPE.specialLetter
    else
        return LETTER_TYPE.unknown
    end
end
local function separateHangeul(charCode)
    local separated = {}
    separated.cho = math.floor((charCode - 44032) / 28 / 21)
    separated.jung = math.floor(((charCode - 44032) / 28) % 21)
    separated.jong = math.floor((charCode - 44032) % 28)
    return 
end
local function numglify(char)
    print(char)
    print(utf8.codepoint(char))
    local charCode = utf8.codepoint(char)
    local letterType = getLetterType(charCode)
    return letterType
end
local function numglifyString(text)
    local str = ""

    for i = 1, utf8.len(text)
    do
        str = str .. numglify(utf8.sub(text, i, i))
    end
    return str
end

http.createServer(function(req, res)
    local body = numglifyString(decodeURI(req.url:sub(2)))
    res:setHeader("Content-Type", "text/html; charset=utf-8")
    res:setHeader("Content-Length", #body)
    res:finish(body)
end):listen(port)
