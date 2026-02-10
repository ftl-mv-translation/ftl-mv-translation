--Обновленный код для ру версии, сделал 𝐄𝐯𝐢𝐥 𝐏𝐞𝐩𝐩𝐞𝐫𝐏𝐥𝐚𝐲𝐳

--[[
////////////////////
DATA & UTIL
////////////////////
]]--

local gatlingName = ""
local gatlingNameStorage = ""
local gatlingNameCharMax = 11
local gatlingNameEventText = nil -- This one doubles as a tracker to see if we're currently writing the name
local cursorVisible = true
local cursorTimer = 0

local time_increment = mods.multiverse.time_increment
local function set_gatling_event_text(choiceBox)
    choiceBox.mainText = string.format(gatlingNameEventText or "", cursorVisible and gatlingName.."_" or gatlingName)
end
local function save_gatling_name()
    for i = 1, string.len(gatlingNameStorage) do
        local c = string.sub(gatlingNameStorage, i, i)
        Hyperspace.playerVariables["loc_gatling_name_"..tostring(i)] = string.byte(c)
    end
    if string.len(gatlingNameStorage) < gatlingNameCharMax then
        for i = string.len(gatlingNameStorage) + 1, gatlingNameCharMax do
            Hyperspace.playerVariables["loc_gatling_name_"..tostring(i)] = 0
        end
    end
end

local function latin_to_russian(str)
    local ruLower = {
        a = "ф", s = "ы", d = "в", f = "а", g = "п",
        h = "р", j = "о", k = "л", l = "д", q = "й",
        w = "ц", e = "у", r = "к", t = "е", y = "н",
        u = "г", i = "ш", o = "щ", p = "з",
        z = "я", x = "ч", c = "с", v = "м", b = "и",
        n = "т", m = "ь"
    }
    local ruUpper = {
        a = "Ф", s = "Ы", d = "В", f = "А", g = "П",
        h = "Р", j = "О", k = "Л", l = "Д", q = "Й",
        w = "Ц", e = "У", r = "К", t = "Е", y = "Н",
        u = "Г", i = "Ш", o = "Щ", p = "З",
        z = "Я", x = "Ч", c = "С", v = "М", b = "И",
        n = "Т", m = "Ь"
    }
    local out = {}
    for i = 1, #str do
        local ch = string.sub(str, i, i)
        if ch:match("%l") then
            out[#out + 1] = ruLower[ch] or ch
        elseif ch:match("%u") then
            local lower = string.lower(ch)
            out[#out + 1] = ruUpper[lower] or ch
        elseif ch == "[" then
            out[#out + 1] = "х"
        elseif ch == "{" then
            out[#out + 1] = "Х"
        elseif ch == "]" then
            out[#out + 1] = "ъ"
        elseif ch == "}" then
            out[#out + 1] = "Ъ"
        elseif ch == "," then
            out[#out + 1] = "б"
        elseif ch == "<" then
            out[#out + 1] = "Б"
        elseif ch == "." then
            out[#out + 1] = "ю"
        elseif ch == ">" then
            out[#out + 1] = "Ю"
        elseif ch == ";" then
            out[#out + 1] = "ж"
        elseif ch == ":" then
            out[#out + 1] = "Ж"
        elseif ch == "'" then
            out[#out + 1] = "э"
        elseif ch == "\"" then
            out[#out + 1] = "Э"
        elseif ch == "\\" or ch == "`" then
            out[#out + 1] = "ё"
        elseif ch == "|" or ch == "~" then
            out[#out + 1] = "Ё"
        elseif ch == "@" then
            out[#out + 1] = "\""
        else
            out[#out + 1] = ch
        end
    end
    return table.concat(out)
end

local function load_gatling_name()
    gatlingName = ""
    gatlingNameStorage = ""
    for i = 1, gatlingNameCharMax do
        local cByte = Hyperspace.playerVariables["loc_gatling_name_"..tostring(i)]
        if cByte == 0 then break end
        gatlingNameStorage = gatlingNameStorage..string.char(cByte)
    end
    if #gatlingNameStorage > 0 then
        gatlingName = latin_to_russian(gatlingNameStorage)
    end
end
local function set_gatling_name(title, shortTitle)
    local gatlingDesc = Hyperspace.Blueprints:GetWeaponBlueprint("GATLING").desc
    gatlingDesc.title.data = title or ("\""..gatlingName.."\"")
    gatlingDesc.shortTitle.data = shortTitle or (gatlingName)
end

--[[
////////////////////
LOGIC
////////////////////
]]--

-- Track if the shift key is being held down
local holdingShift = false
script.on_internal_event(Defines.InternalEvents.ON_KEY_DOWN, function(key)
    if key == 304 then holdingShift = true end
end)
script.on_internal_event(Defines.InternalEvents.ON_KEY_UP, function(key)
    if key == 304 then holdingShift = false end
end)

-- Load saved gatling name when continuing a run
local loadGatlingName = false
script.on_init(function(newGame)
    -- The storage check event evaporates when loading the game, so may as well
    -- turn this off to make sure it doesn't screw with another event
    gatlingNameEventText = nil
    if newGame then
        -- Reset the gatling name for a new run
        set_gatling_name("Орудие Гатлинга", "Гатлинг")
    else
        loadGatlingName = true
    end
end)
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if loadGatlingName then
        loadGatlingName = false
        load_gatling_name()
        if string.len(gatlingName) > 0 then
            set_gatling_name()
        end
    end
end)

-- Init and complete gatling naming
script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, function(choiceBox, event)
    if event.eventName == "STORAGE_CHECK_GATLING_NAME_CUSTOM" then
        gatlingNameEventText = choiceBox.mainText
        set_gatling_event_text(choiceBox)
    end
end)
script.on_game_event("STORAGE_CHECK_GATLING_NAME_CUSTOM_END", false, function()
    gatlingNameEventText = nil
    if string.len(gatlingName) > 0 then
        save_gatling_name()
        set_gatling_name()
    end
end)

-- Blink typing cursor
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if Hyperspace.App.world.bStartedGame and gatlingNameEventText then
        cursorTimer = cursorTimer + time_increment(false)
        if cursorTimer >= 0.5 then
            cursorTimer = 0
            cursorVisible = not cursorVisible
            set_gatling_event_text(Hyperspace.App.gui.choiceBox)
        end
    end
end)

-- Writing the gatling name
local charWhitelist = {" ", "'", "-", "."}
do
    local charWhiteListTmp = {}
    for _, char in ipairs(charWhitelist) do charWhiteListTmp[string.byte(char)] = true end
    charWhitelist = charWhiteListTmp
end

script.on_internal_event(Defines.InternalEvents.ON_KEY_DOWN, function(key)
    if Hyperspace.App.world.bStartedGame and gatlingNameEventText then
        -- Get typed character
        local char
        local storageChar
        if string.len(gatlingNameStorage) < gatlingNameCharMax then
            if key >= 97 and key <= 122 then
                local latin = string.char(key)
                local ruLower = {
                    a = "ф", s = "ы", d = "в", f = "а", g = "п",
                    h = "р", j = "о", k = "л", l = "д", q = "й",
                    w = "ц", e = "у", r = "к", t = "е", y = "н",
                    u = "г", i = "ш", o = "щ", p = "з",
                    z = "я", x = "ч", c = "с", v = "м", b = "и",
                    n = "т", m = "ь"
                }
                local ruUpper = {
                    a = "Ф", s = "Ы", d = "В", f = "А", g = "П",
                    h = "Р", j = "О", k = "Л", l = "Д", q = "Й",
                    w = "Ц", e = "У", r = "К", t = "Е", y = "Н",
                    u = "Г", i = "Ш", o = "Щ", p = "З",
                    z = "Я", x = "Ч", c = "С", v = "М", b = "И",
                    n = "Т", m = "Ь"
                }
                if holdingShift then
                    char = ruUpper[latin]
                    storageChar = string.char(key - 32)
                else
                    char = ruLower[latin]
                    storageChar = latin
                end
            elseif key == 91 then -- [
                char = holdingShift and "Х" or "х"
                storageChar = holdingShift and "{" or "["
            elseif key == 93 then -- ]
                char = holdingShift and "Ъ" or "ъ"
                storageChar = holdingShift and "}" or "]"
            elseif key == 44 then -- ,
                char = holdingShift and "Б" or "б"
                storageChar = holdingShift and "<" or ","
            elseif key == 46 then -- .
                char = holdingShift and "Ю" or "ю"
                storageChar = holdingShift and ">" or "."
            elseif key == 59 then -- ;
                char = holdingShift and "Ж" or "ж"
                storageChar = holdingShift and ":" or ";"
            elseif key == 39 then -- '
                char = holdingShift and "Э" or "э"
                storageChar = holdingShift and "\"" or "'"
            elseif key == 92 then -- \
                char = holdingShift and "Ё" or "ё"
                storageChar = holdingShift and "|" or "\\"
            elseif key == 96 then -- `
                char = holdingShift and "Ё" or "ё"
                storageChar = holdingShift and "~" or "`"
            elseif key == 50 and holdingShift then -- 2
                char = "\""
                storageChar = "@"
            elseif charWhitelist[key] then
                char = string.char(key)
                storageChar = char
            end
        end

        -- Add typed character or delete the last one
        if char then
            gatlingName = gatlingName..char
            gatlingNameStorage = gatlingNameStorage..storageChar
            set_gatling_event_text(Hyperspace.App.gui.choiceBox)
        elseif key == 8 then
            gatlingNameStorage = string.sub(gatlingNameStorage, 1, -2)
            gatlingName = latin_to_russian(gatlingNameStorage)
            set_gatling_event_text(Hyperspace.App.gui.choiceBox)
        end
    end
end)
