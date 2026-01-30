--[[
////////////////////
DATA & UTIL
////////////////////
]]--

local gatlingName = ""
local gatlingNameCharMax = 11
local gatlingNameEventText = nil -- This one doubles as a tracker to see if we're currently writing the name
local cursorVisible = true
local cursorTimer = 0

local time_increment = mods.multiverse.time_increment
local function set_gatling_event_text(choiceBox)
    choiceBox.mainText = string.format(gatlingNameEventText or "", cursorVisible and gatlingName.."_" or gatlingName)
end
local function save_gatling_name()
    for i = 1, string.len(gatlingName) do
        local c = string.sub(gatlingName, i, i)
        Hyperspace.playerVariables["loc_gatling_name_"..tostring(i)] = string.byte(c)
    end
    if string.len(gatlingName) < gatlingNameCharMax then
        for i = string.len(gatlingName) + 1, gatlingNameCharMax do
            Hyperspace.playerVariables["loc_gatling_name_"..tostring(i)] = 0
        end
    end
end
local function load_gatling_name()
    gatlingName = ""
    for i = 1, gatlingNameCharMax do
        local cByte = Hyperspace.playerVariables["loc_gatling_name_"..tostring(i)]
        if cByte == 0 then break end
        gatlingName = gatlingName..string.char(cByte)
    end
end
local function set_gatling_name(title, shortTitle)
    local gatlingDesc = Hyperspace.Blueprints:GetWeaponBlueprint("GATLING").desc
    gatlingDesc.title.data = title or ("'"..gatlingName.."'")
    gatlingDesc.shortTitle.data = shortTitle or ("'"..gatlingName.."'")
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
        set_gatling_name("Mitrailleuse Gatling", "Gatling")
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
        if string.len(gatlingName) < gatlingNameCharMax then
            if key >= 97 and key <= 122 then
                if holdingShift then
                    char = string.char(key - 32)
                else
                    char = string.char(key)
                end
            elseif charWhitelist[key] then
                char = string.char(key)
            end
        end

        -- Add typed character or delete the last one
        if char then
            gatlingName = gatlingName..char
            set_gatling_event_text(Hyperspace.App.gui.choiceBox)
        elseif key == 8 then
            gatlingName = string.sub(gatlingName, 1, -2)
            set_gatling_event_text(Hyperspace.App.gui.choiceBox)
        end
    end
end)
