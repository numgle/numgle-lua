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
local function indexOf(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end
    return nil
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
handlerTable = {
    [LETTER_TYPE.empty] = function(charCode) return "" end,
    [LETTER_TYPE.completeHangeul] = function(charCode)
        return completeHangeul(utf8.char(charCode))
    end,
    [LETTER_TYPE.notCompleteHangeul] = function(charCode)
        return data.han[charCode - data.range.notCompleteHangul.start + 1]
    end,
    [LETTER_TYPE.englishUpper] = function(charCode)
        return data.englishUpper[charCode - data.range.uppercase.start + 1]
    end,
    [LETTER_TYPE.englishLower] = function(charCode)
        return data.englishLower[charCode - data.range.lowercase.start + 1]
    end,
    [LETTER_TYPE.number] = function(charCode)
        return data.number[charCode - data.range.number.start + 1]
    end,
    [LETTER_TYPE.specialLetter] = function(charCode)
        return data.special[indexOf(data.range.special, charCode)]
    end,
    [LETTER_TYPE.unknown] = function(charCode) return "" end
}
function getLetterType(charCode)
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
function separateHangeul(charCode)
    local separated = {}
    separated.cho = math.floor((charCode - 44032) / 28 / 21)
    separated.jung = math.floor(((charCode - 44032) / 28) % 21)
    separated.jong = math.floor((charCode - 44032) % 28)
    return separated
end
function isInData(separated)
    if separated.jong ~= 0 and data.jong[separated.jong + 1] == "" then
        return false
    elseif separated.jung >= 8 and separated.jung ~= 20 then
        return data.jung[separated.jung - 7] ~= ""
    else
        return data.cj[math.min(8, separated.jung) + 1][separated.cho + 1] ~= ""
    end
end
function completeHangeul(char)
    local separated = separateHangeul(utf8.codepoint(char))

    if not isInData(separated) then
        return ""
    elseif separated.jung >= 8 and separated.jung ~= 20 then
        return data.jong[separated.jong + 1] .. data.jung[separated.jung - 7] .. data.cho[separated.cho + 1]
    else return data.jong[separated.jong + 1] .. data.cj[math.min(8, separated.jung) + 1][separated.cho + 1]
    end
end
function numglify(char)
    local charCode = utf8.codepoint(char)
    local letterType = getLetterType(charCode)

    return handlerTable[letterType](charCode)
end
function numglifyString(text)
    local str = ""

    for i = 1, utf8.len(text)
    do
        str = str .. numglify(utf8.sub(text, i, i)) .. "<br>"
    end
    return str
end

http.createServer(function(req, res)
    if req.url == "/favicon.ico" then
        return
    end
    local body = numglifyString(decodeURI(req.url:sub(2)))
    res:setHeader("Content-Type", "text/html; charset=utf-8")
    res:setHeader("Content-Length", #body)
    res:finish(body)
end):listen(port)
