--[[
////////////////////
WARNINGS SILENCER
////////////////////
]]--
-- This muffles IDE warnings about undefined variables provided by Hyperspace
Hyperspace = Hyperspace or {}
Graphics = Graphics or {}
script = script or {}
Defines = Defines or {}
mods = mods or {}
log = log or {}
RapidXML = RapidXML or {}


--[[
////////////////////
INIT
////////////////////
]]--

-- Initialize the multiverse table - necessary so addond devs don't do something stupid with the same variables
mods.multiverse = {}

-- System IDs
mods.multiverse.systemIds = {
    [0] = "shields",
    "engines",
    "oxygen",
    "weapons",
    "drones",
    "medbay",
    "piloting",
    "sensors",
    "doors",
    "teleporter",
    "cloaking",
    "artillery",
    "battery",
    "clonebay",
    "mind",
    "hacking",
    [20] = "temporal"
}

-- Blueprint file paths
mods.multiverse.blueprintFiles = {
    "data/blueprints.xml",
    "data/dlcBlueprints.xml",
}

-- Integer min and max
mods.multiverse.INT_MAX = 2147483647
mods.multiverse.INT_MIN = -2147483648

-- Update print position
Hyperspace.PrintHelper.GetInstance().x = 150

--[[
////////////////////
UTILITY FUNCTIONS
////////////////////
]]--

-- Replace all instances of a substring inside a string
function mods.multiverse.string_replace(str, old, new)
    str = tostring(str)
    old = tostring(old)
    new = tostring(new)
    local pos = string.find(str, old)
    while pos do
        str = string.sub(str, 1, pos - 1)..new..string.sub(str, pos + #old, #str)
        pos = string.find(str, old)
    end
    return str
end
local string_replace = mods.multiverse.string_replace

-- Call the callback on the value if it exists, otherwise give the value
function mods.multiverse.cbwrap(value, callback)
    if callback ~= nil and type(callback) ~= "function" then
        error("callback must be nil or a function", 2)
    end
    return callback and callback(value) or value
end
local cbwrap = mods.multiverse.cbwrap

-- Convert a Lua table to a comma delimited list string
function mods.multiverse.table_to_list_string(tbl, delimiter, toStrFunc)
    if #tbl == 0 then
        return ""
    elseif #tbl == 1 then
        return cbwrap(tbl[1], toStrFunc)
    end
    delimiter = delimiter or ", "
    if #tbl == 2 then
        return cbwrap(tbl[1], toStrFunc)..delimiter..cbwrap(tbl[2], toStrFunc)
    else
        local res = cbwrap(tbl[1], toStrFunc)
        for i = 2, #tbl - 1 do
            res = res..", "..cbwrap(tbl[i], toStrFunc)
        end
        return res..delimiter..cbwrap(tbl[#tbl], toStrFunc)
    end
end
local table_to_list_string = mods.multiverse.table_to_list_string

-- Iterator for C vectors
function mods.multiverse.vter(cvec)
    if not (type(cvec) == "userdata") then
        error("invalid arg passed to vter ("..tostring(cvec)..")", 2)
    end
    local i = -1
    local n = cvec:size()
    return function()
        i = i + 1
        if i < n then return cvec[i] end
    end
end
local vter = mods.multiverse.vter

-- Convert a number to its sign (-1 for negatives, 1 for positives or 0).
function mods.multiverse.sign(n)
    return n > 0 and 1 or (n == 0 and 0 or -1)
end
local sign = mods.multiverse.sign

-- Simple linear interpolation
function mods.multiverse.lerp(a, b, f)
    return a*(1.0 - f) + b*f;
end
local lerp = mods.multiverse.lerp

-- Check if one string starts with another string
function mods.multiverse.string_starts(str, start)
    return string.sub(str, 1, string.len(start)) == start
end
local string_starts = mods.multiverse.string_starts

-- Get a table for a userdata value by a given name.
-- Useful for distinguishing tables with namespaces for compatibility with other mods.
function mods.multiverse.userdata_table(userdata, tableName)
    if not (userdata and userdata.table and type(userdata) == "userdata" and type(tableName) == "string") then
        error("invalid arg passed to userdata_table ("..tostring(userdata)..", "..tostring(tableName)..")", 2)
    end
    if not userdata.table[tableName] then userdata.table[tableName] = {} end
    return userdata.table[tableName]
end
local userdata_table = mods.multiverse.userdata_table

-- Run this on a weapon to reduce its charge incrementally as though the weapon system wasn't powered.
function mods.multiverse.reduce_weapon_charge(ship, weapon)
    if weapon.cooldown.first > 0 then
        if weapon.cooldown.first >= weapon.cooldown.second then
            weapon.chargeLevel = weapon.chargeLevel - 1
        end
        local gameSpeed = Hyperspace.FPS.SpeedFactor
        local autoCooldown = 1 + ship:GetAugmentationValue("AUTO_COOLDOWN")
        weapon.cooldown.first = weapon.cooldown.first - 0.375*gameSpeed - autoCooldown*gameSpeed/16
        if weapon.cooldown.first <= 0 then
            weapon.cooldown.first = 0
            weapon.chargeLevel = 0
        end
    else
        weapon.chargeLevel = 0
    end
    weapon.table["mods.multiverse.manualDecharge"] = true
end
script.on_internal_event(Defines.InternalEvents.CONSTRUCT_PROJECTILE_FACTORY, function(weapon)
    weapon.table["mods.multiverse.manualDecharge"] = false
end)
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if ship and ship.weaponSystem and ship.weaponSystem.weapons then
        for weapon in vter(ship.weaponSystem.weapons) do
            weapon.table["mods.multiverse.manualDecharge"] = false
        end
    end
end)
local reduce_weapon_charge = mods.multiverse.reduce_weapon_charge

-- Use this to fix projectiles that aren't fired corrently,
-- like those that are fired by a 0-power weapon while the weapon system isn't powered.
function mods.multiverse.push_projectiles_to_world(weapon)
    local projectile = weapon:GetProjectile()
    while projectile do
        Hyperspace.App.world.space.projectiles:push_back(projectile)
        projectile = weapon:GetProjectile()
    end
end
local push_projectiles_to_world = mods.multiverse.push_projectiles_to_world

-- Check if a weapon's current shot is its first.
-- Second arg should be true if this check will run after the first shot has been fired.
function mods.multiverse.is_first_shot(weapon, afterFirstShot)
    local shots = weapon.numShots
    if weapon.weaponVisual.iChargeLevels > 0 then shots = shots*(weapon.weaponVisual.boostLevel + 1) end
    if weapon.blueprint.miniProjectiles:size() > 0 then shots = shots*weapon.blueprint.miniProjectiles:size() end
    if afterFirstShot then shots = shots - 1 end
    return shots == weapon.queuedProjectiles:size()
end
local is_first_shot = mods.multiverse.is_first_shot

-- Return a value equal to the time that passes during a single tick or frame.
-- This means that if you have an ON_TICK function that adds "time_increment()"
-- to a variable, that variable will act as a timer.
function mods.multiverse.time_increment(useSpeed) --If useSpeed is true, the returned value will properly scale with game speed. Otherwise, the returned value will allow for timers that are independent of framerate, game speed, etc.
    if useSpeed or useSpeed == nil then
        return Hyperspace.FPS.SpeedFactor/16
    elseif Hyperspace.FPS.NumFrames ~= 0 then --At some points this may be equal to zero (such as when the game is being loaded). In such cases we wouldn't want time to pass, and we certainly would not want division by zero.
        return 1/Hyperspace.FPS.NumFrames
    else
        return 0
    end
end
local time_increment = mods.multiverse.time_increment

-- Flash alpha from 0, to 1, to 0 over a given time
-- Equivalent of AnimationTracker::GetAlphaLevel
function mods.multiverse.alpha_pulse(time, timeCurrent)
    return 1 - math.abs(timeCurrent*(2/time) - 1)
end
local alpha_pulse = mods.multiverse.alpha_pulse

-- Get the tint for background sprites based on current hull and pause
function mods.multiverse.background_tint()
    local ship = Hyperspace.ships.player
    local healthFactor = ship and (1 - ship.ship.hullIntegrity.first/ship.ship.hullIntegrity.second) or 1
    local r, g ,b
    if Hyperspace.App.world.space.gamePaused then
        g = 0.4
        r = healthFactor*0.4 + 0.4
    else
        g = 1.0 - healthFactor*healthFactor*0.5
        r = 1.0
    end
    b = g
    return Graphics.GL_Color(r, g, b, 1)
end
local background_tint = mods.multiverse.background_tint

-- Find ID of a room at the given location
function mods.multiverse.get_room_at_location(shipManager, location, includeWalls)
    return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end
local get_room_at_location = mods.multiverse.get_room_at_location

-- Returns a table where the indices are the IDs of all rooms adjacent to the given room
-- and the values are the rooms' coordinates
function mods.multiverse.get_adjacent_rooms(shipId, roomId, diagonals)
    local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipId)
    local roomShape = shipGraph:GetRoomShape(roomId)
    local adjacentRooms = {}
    local currentRoom = nil
    local function check_for_room(x, y)
        currentRoom = shipGraph:GetSelectedRoom(x, y, false)
        if currentRoom > -1 and not adjacentRooms[currentRoom] then
            adjacentRooms[currentRoom] = Hyperspace.Pointf(x, y)
        end
    end
    for offset = 0, roomShape.w - 35, 35 do
        check_for_room(roomShape.x + offset + 17, roomShape.y - 17)
        check_for_room(roomShape.x + offset + 17, roomShape.y + roomShape.h + 17)
    end
    for offset = 0, roomShape.h - 35, 35 do
        check_for_room(roomShape.x - 17,               roomShape.y + offset + 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + offset + 17)
    end
    if diagonals then
        check_for_room(roomShape.x - 17,               roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + roomShape.h + 17)
        check_for_room(roomShape.x - 17,               roomShape.y + roomShape.h + 17)
    end
    return adjacentRooms
end
local get_adjacent_rooms = mods.multiverse.get_adjacent_rooms

-- Check if a given crew member is being mind controlled by a ship system
function mods.multiverse.under_mind_system(crewmem)
    local controlledCrew = nil
    pcall(function() controlledCrew = Hyperspace.ships(1 - crewmem.iShipId).mindSystem.controlledCrew end)
    if controlledCrew then
        for crew in vter(controlledCrew) do
            if crewmem == crew then
                return true
            end
        end
    end
    return false
end
local under_mind_system = mods.multiverse.under_mind_system

-- Check if a given crew member is resistant to mind control
function mods.multiverse.resists_mind_control(crew)
    return select(2, crew.extend:CalculateStat(Hyperspace.CrewStat.RESISTS_MIND_CONTROL))
end
local resists_mind_control = mods.multiverse.resists_mind_control

-- Check if a given crew member can be mind controlled
function mods.multiverse.can_be_mind_controlled(crewmem)
    return not (crewmem:IsDrone() or resists_mind_control(crewmem)) and not under_mind_system(crewmem)
end
local can_be_mind_controlled = mods.multiverse.can_be_mind_controlled

-- Returns a table of all crew belonging to the given ship on the room tile at the given point
function mods.multiverse.get_ship_crew_point(shipManager, x, y, maxCount)
    res = {}
    x = x//35
    y = y//35
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.iShipId == shipManager.iShipId and x == crewmem.x//35 and y == crewmem.y//35 then
            table.insert(res, crewmem)
            if maxCount and #res >= maxCount then
                return res
            end
        end
    end
    return res
end
local get_ship_crew_point = mods.multiverse.get_ship_crew_point

-- Spawn a temporary drone with a limited number of shots
function mods.multiverse.spawn_temp_drone(bp, ownerShip, targetShip, targetLocation, shots, position)
    local drone = ownerShip:CreateSpaceDrone(bp)
    drone.powerRequired = 0
    drone:SetMovementTarget(targetShip._targetable)
    drone:SetWeaponTarget(targetShip._targetable)
    drone.lifespan = shots or 2
    drone.powered = true
    drone:SetDeployed(true)
    drone.bDead = false
    if position then drone:SetCurrentLocation(position) end
    if targetLocation then drone.targetLocation = targetLocation end
    drone.table["mods.multiverse.isTempDrone"] = true
    return drone
end
local spawn_temp_drone = mods.multiverse.spawn_temp_drone

-- Clear temporary drones when their ship is out of the fight
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    for drone in vter(Hyperspace.App.world.space.drones) do
        if drone.table and drone.table["mods.multiverse.isTempDrone"] and (drone.iShipId == 0 or drone.iShipId == 1) then
            local ship = Hyperspace.ships(drone.iShipId)
            if not ship or ship.bDestroyed or not ship._targetable.hostile then
                drone:SetDestroyed(true, true)
            end
        end
    end
end)

-- Check if the game is in any pause state
function mods.multiverse.check_paused()
    return Hyperspace.App.gui.bPaused or Hyperspace.App.gui.menu_pause or Hyperspace.App.gui.event_pause or Hyperspace.App.gui.bAutoPaused
end
local check_paused = mods.multiverse.check_paused

-- System and function for creating custom damage messages
do
    local customDamageMessages = {}
    local function clear_damage_messages()
        for i = 1, #customDamageMessages do
            table.remove(customDamageMessages)
        end
    end
    function mods.multiverse.create_damage_message(shipId, sprite, x, y)
        table.insert(customDamageMessages, {
            shipId = shipId,
            sprite = sprite,
            x = math.random(21) - 11 + x,
            y = y - 30,
            lifetime = 1
        })
    end
    script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
        if not check_paused() then
            local messageCount = #customDamageMessages
            local index = 1
            while index <= messageCount do
                local damageMessage = customDamageMessages[index]
                damageMessage.lifetime = damageMessage.lifetime - time_increment()
                if damageMessage.lifetime <= 0 then
                    table.remove(customDamageMessages, index)
                    messageCount = messageCount - 1
                else
                    index = index + 1
                end
            end
        end
        if Hyperspace.App.menu.bOpen or Hyperspace.App.menu.shipBuilder.bOpen then
            clear_damage_messages()
        end
    end)
    script.on_game_event("START_BEACON", false, clear_damage_messages)
    script.on_render_event(Defines.RenderEvents.SHIP_MANAGER, function() end, function(ship)
        for _, damageMessage in ipairs(customDamageMessages) do
            if damageMessage.shipId == ship.iShipId then
                Graphics.CSurface.GL_PushMatrix()
                Graphics.CSurface.GL_Translate(damageMessage.x, damageMessage.y - 10*(1 - damageMessage.lifetime))
                Graphics.CSurface.GL_RenderPrimitive(damageMessage.sprite)
                Graphics.CSurface.GL_PopMatrix()
            end
        end
    end)
end
local create_damage_message = mods.multiverse.create_damage_message

-- Calculate a new point position from an old position, an angle, and a distance
function mods.multiverse.offset_point_direction(oldX, oldY, angle, distance)
    local newX = oldX + (distance * math.cos(math.rad(angle)))
    local newY = oldY + (distance * math.sin(math.rad(angle)))
    return Hyperspace.Pointf(newX, newY)
end
local offset_point_direction = mods.multiverse.offset_point_direction

-- Get the distance between two points
function mods.multiverse.get_distance(point1, point2)
    return math.sqrt((point2.x - point1.x)^2 + (point2.y - point1.y)^2)
end
local get_distance = mods.multiverse.get_distance

-- Sprites for custom damage messages
mods.multiverse.damageMessages = {}
local damageMessages = mods.multiverse.damageMessages
do
    local function setup_damage_message(path)
        local messageTex = Hyperspace.Resources:GetImageId(path)
        return Hyperspace.Resources:CreateImagePrimitive(messageTex, -messageTex.width/2, -messageTex.height/2, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
    end
    damageMessages.ONE = setup_damage_message("numbers/Text_1_L.png")
    damageMessages.NEGATED = setup_damage_message("numbers/text_negate.png")
end

-- Custom callback events for loading a save and starting a new game
local newGameFunctions = {}
local loadGameFunctions = {}
local startGameFlag = nil
script.on_init(function(newGame) startGameFlag = newGame end)
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if startGameFlag ~= nil then
        if startGameFlag then
            for _, newGameFunction in ipairs(newGameFunctions) do
                newGameFunction()
            end
        else
            for _, loadGameFunction in ipairs(loadGameFunctions) do
                loadGameFunction()
            end
        end
        startGameFlag = nil
    end
end)
function mods.multiverse.on_new_game(callback)
    table.insert(newGameFunctions, callback)
end
local on_new_game = mods.multiverse.on_new_game
function mods.multiverse.on_load_game(callback)
    table.insert(loadGameFunctions, callback)
end
local on_load_game = mods.multiverse.on_load_game

--[[
////////////////////
SPEED UI
////////////////////
]]--
-- Variant 1
local slowButton = Hyperspace.Button()
slowButton:OnInit("statusUI/top_speed_slow", Hyperspace.Point(530, -6))
slowButton.hitbox.x = 8 + slowButton.position.x
slowButton.hitbox.y = 8 + slowButton.position.y
slowButton.hitbox.w = 20
slowButton.hitbox.h = 20
local normButton = Hyperspace.Button()
normButton:OnInit("statusUI/top_speed_normal", Hyperspace.Point(555, -6))
normButton.hitbox.x = 8 + normButton.position.x
normButton.hitbox.y = 8 + normButton.position.y
normButton.hitbox.w = 20
normButton.hitbox.h = 20
local fastButton = Hyperspace.Button()
fastButton:OnInit("statusUI/top_speed_fast", Hyperspace.Point(580, -6))
fastButton.hitbox.x = 8 + fastButton.position.x
fastButton.hitbox.y = 8 + fastButton.position.y
fastButton.hitbox.w = 20
fastButton.hitbox.h = 20
local selectedButton = 2
local ipsButtons = {slowButton, normButton, fastButton}

-- Variant 2
local playButton = Hyperspace.Button()
playButton:OnInit("statusUI/top_speed_play", Hyperspace.Point(580, -6))
playButton.hitbox.x = 8 + playButton.position.x
playButton.hitbox.y = 8 + playButton.position.y
playButton.hitbox.w = 20
playButton.hitbox.h = 20
local pauseButton = Hyperspace.Button()
pauseButton:OnInit("statusUI/top_speed_pause", Hyperspace.Point(580, -6))
pauseButton.hitbox.x = 8 + pauseButton.position.x
pauseButton.hitbox.y = 8 + pauseButton.position.y
pauseButton.hitbox.w = 20
pauseButton.hitbox.h = 20
local upButton = Hyperspace.Button()
upButton:OnInit("statusUI/top_speed_up", Hyperspace.Point(530, -6))
upButton.hitbox.x = 8 + upButton.position.x
upButton.hitbox.y = 8 + upButton.position.y
upButton.hitbox.w = 20
upButton.hitbox.h = 9
local downButton = Hyperspace.Button()
downButton:OnInit("statusUI/top_speed_down", Hyperspace.Point(530, 5))
downButton.hitbox.x = 8 + downButton.position.x
downButton.hitbox.y = 8 + downButton.position.y
downButton.hitbox.w = 20
downButton.hitbox.h = 9
local numberImage = {
    image = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/top_speed_number.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
    x = 555,
    y = -6
}

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if not Hyperspace.App.world.bStartedGame then return end

    local mousePos = Hyperspace.Mouse.position
    if Hyperspace.metaVariables.speedui_setting == 1 then
        for i, button in ipairs(ipsButtons) do
            button.bActive = (selectedButton ~= i)
            button:MouseMove(mousePos.x, mousePos.y, false)
        end
        selectedButton = (Hyperspace.FPS.speedLevel < 0 and 1) or (Hyperspace.FPS.speedLevel == 0 and 2) or 3
    elseif Hyperspace.metaVariables.speedui_setting == 2 then
        local speedLimit = (Hyperspace.Settings.frameLimit or Hyperspace.Settings.vsync) and 2 or 99
        local currSpeed = Hyperspace.FPS.speedLevel
        if currSpeed > speedLimit then Hyperspace.FPS.speedLevel = speedLimit
        elseif currSpeed < -2 then Hyperspace.FPS.speedLevel = -2 end

        if Hyperspace.FPS.speedEnabled then
            pauseButton:MouseMove(mousePos.x, mousePos.y, false)
            pauseButton.bActive = true
            playButton.bActive = false
        else
            playButton:MouseMove(mousePos.x, mousePos.y, false)
            playButton.bActive = true
            pauseButton.bActive = false
        end

        upButton.bActive = true
        upButton:MouseMove(mousePos.x, mousePos.y, false)
        if currSpeed >= speedLimit then
            upButton.bActive = false
        end

        downButton.bActive = true
        downButton:MouseMove(mousePos.x, mousePos.y, false)
        if currSpeed <= -2 then
            downButton.bActive = false
        end
    end
end)

script.on_render_event(Defines.RenderEvents.FTL_BUTTON, function() end, function()
    if not Hyperspace.App.world.bStartedGame then return end

    if Hyperspace.metaVariables.speedui_setting == 0 then
        Graphics.CSurface.GL_SetColor(Graphics.GL_Color(1, 1, 1, 1))
        Graphics.freetype.easy_printCenter(51, 573, 18, Hyperspace.Text:GetText("ftl_drive_override"))
    elseif Hyperspace.metaVariables.speedui_setting == 1 then
        for _, button in ipairs(ipsButtons) do button:OnRender() end
    elseif Hyperspace.metaVariables.speedui_setting == 2 then
        local currSpeed = Hyperspace.FPS.speedLevel

        if Hyperspace.FPS.speedEnabled then pauseButton:OnRender()
        else playButton:OnRender() end

        Graphics.CSurface.GL_PushMatrix()
        Graphics.CSurface.GL_Translate(numberImage.x, numberImage.y, 0)
        Graphics.CSurface.GL_RenderPrimitive(numberImage.image)
        Graphics.freetype.easy_printCenter(1, 18, 11, math.floor(currSpeed))
        Graphics.CSurface.GL_PopMatrix()

        upButton:OnRender()
        downButton:OnRender()
    end
end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x,y) 
    if Hyperspace.metaVariables.speedui_setting == 1 then
        if slowButton.bHover and slowButton.bActive then
            Hyperspace.FPS.speedEnabled = true
            Hyperspace.FPS.speedLevel = -2
            selectedButton = 1
            Hyperspace.Sounds:PlaySoundMix("powerUpSystem", -1, false)
        end
        if normButton.bHover and normButton.bActive then
            Hyperspace.FPS.speedEnabled = true
            Hyperspace.FPS.speedLevel = 0
            selectedButton = 2
            Hyperspace.Sounds:PlaySoundMix("powerUpSystem", -1, false)
        end
        if fastButton.bHover and fastButton.bActive then
            Hyperspace.FPS.speedEnabled = true
            Hyperspace.FPS.speedLevel = 2
            selectedButton = 3
            Hyperspace.Sounds:PlaySoundMix("powerUpSystem", -1, false)
        end
    elseif Hyperspace.metaVariables.speedui_setting == 2 then
        selectedButton = 0
        if (playButton.bHover and playButton.bActive) or (pauseButton.bHover and pauseButton.bActive) then
            Hyperspace.FPS.speedEnabled = not Hyperspace.FPS.speedEnabled
        elseif upButton.bHover and upButton.bActive then
            Hyperspace.FPS.speedLevel = Hyperspace.FPS.speedLevel + 1
            Hyperspace.Sounds:PlaySoundMix("powerUpSystem", -1, false)
            Hyperspace.metaVariables.speedui_speed = Hyperspace.FPS.speedLevel
        elseif downButton.bHover and downButton.bActive then
            Hyperspace.FPS.speedLevel = Hyperspace.FPS.speedLevel - 1
            Hyperspace.Sounds:PlaySoundMix("powerUpSystem", -1, false)
            Hyperspace.metaVariables.speedui_speed = Hyperspace.FPS.speedLevel
        end
    end
    return Defines.Chain.CONTINUE
end)

-- Loading back the speed level for variant 2, reset variant 1
script.on_init(function()
    selectedButton = 2
    Hyperspace.FPS.speedLevel = 0
    Hyperspace.FPS.speedEnabled = false
    if Hyperspace.metaVariables.speedui_setting == 2 then
        Hyperspace.FPS.speedLevel = Hyperspace.metaVariables.speedui_speed
    end
end)

--[[
////////////////////
SCREEN TRANSFORMATIONS
////////////////////
]]--

-- Fade screen to and from a solid color.
do
    local color = nil
    local timer = 0

    local fadeIn = 1
    local hold = 1
    local fadeOut = 1

    script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function() end, function()
        if color then
            Graphics.CSurface.GL_DrawRect(0, 0, 1280, 720, color)
            timer = timer + time_increment()
            if timer < fadeIn then
                color.a = timer / fadeIn
            elseif timer < fadeIn + hold then
                color.a = 1
            elseif timer < fadeIn + hold + fadeOut then
                color.a = 1 - ((timer - fadeIn - hold) / fadeOut)
            else
                color = nil
                timer = 0
            end
        end
    end)

    function mods.multiverse.screen_fade(colorArg, fadeInArg, holdArg, fadeOutArg)
        color = colorArg
        color.a = 0;
        fadeIn = fadeInArg or 1
        hold = holdArg or 1
        fadeOut = fadeOutArg or 1
    end
end

-- Make the screen shake for a given amount of time.
do
    local shakeTime = 0
    local shakeTimeCurrent = 0
    local shakeIntensity = 0

    local function gen_shake_pos()
        if shakeTime <= 0 then return 0 end
        return shakeTimeCurrent/shakeTime*(math.random(shakeIntensity) - 1)
    end

    script.on_render_event(Defines.RenderEvents.GUI_CONTAINER, 
    function()
        if shakeTimeCurrent > 0 then
            Graphics.CSurface.GL_PushMatrix()
            Graphics.CSurface.GL_Translate(gen_shake_pos(), gen_shake_pos())
        end
    end, function()
        if shakeTimeCurrent > 0 then
            Graphics.CSurface.GL_PopMatrix()
            shakeTimeCurrent = math.max(0, shakeTimeCurrent - time_increment())
        end
    end)

    mods.multiverse.screen_shake = function(time, intensity)
        shakeTime = time
        shakeTimeCurrent = time
        shakeIntensity = (intensity or 10) + 1
    end
end

--[[
////////////////////
SYSTEM PREVIEW
////////////////////
]]--
-- Show uninstalled systems in hangar.
-- For Addon Custom System to show you have to do in your lua file:
-- mods.multiverse.systemIcons[Hyperspace.ShipSystem.NameToSystemId("sys_name")] = mods.multiverse.register_system_icon("sys_name")

-- List of systems to show preview for
mods.multiverse.systemIcons = {}
local systemIcons = mods.multiverse.systemIcons

do
    -- Collect system icons
    function mods.multiverse.register_system_icon(name)
        local tex = Hyperspace.Resources:GetImageId("icons/s_"..name.."_overlay.png")
        return Graphics.CSurface.GL_CreateImagePrimitive(tex, 0, 0, 32, 32, 0, Graphics.GL_Color(1, 1, 1, 0.5))
    end
    local register_system_icon = mods.multiverse.register_system_icon

    -- System Icons for the base Multiverse Systems
    for id, sys in pairs(mods.multiverse.systemIds) do
        systemIcons[id] = register_system_icon(sys)
    end

    local roomPreviewTimer = 0

    local function render_system_icon(sysTable, roomId, ship)
        local iconOffset = 22

        -- Check if any of the systems in the room are already on the ship.
        for _, sysId in ipairs(sysTable) do
            if ship:HasSystem(sysId) then return end
        end

        -- Render background
        local sysRoomShape = Hyperspace.ShipGraph.GetShipInfo(ship.iShipId):GetRoomShape(roomId)
        local outlineSize = 2
        Graphics.CSurface.GL_DrawRect(sysRoomShape.x, sysRoomShape.y, sysRoomShape.w, sysRoomShape.h, Graphics.GL_Color(0, 0, 0, 0.3))
        Graphics.CSurface.GL_DrawRectOutline(sysRoomShape.x + outlineSize, sysRoomShape.y + outlineSize, sysRoomShape.w - 2*outlineSize, sysRoomShape.h - 2*outlineSize, Graphics.GL_Color(0.8, 0, 0, 0.5), outlineSize)

        --Determine what room shape this is.
        local roomSize = 1
        if sysRoomShape.w >= 70 and sysRoomShape.h >= 70 then roomSize = 4
        elseif sysRoomShape.w >= 70 then roomSize = 2
        elseif sysRoomShape.h >= 70 then roomSize = 3 end

        --Work out what the maximum number of icons we can show in this room is
        local maxIcons = roomSize == 2 and 3 or roomSize

        local pages = math.ceil(#sysTable/maxIcons)
        local currentIcons = math.min(#sysTable, maxIcons)

        local iconRenderX = sysRoomShape.x + sysRoomShape.w//2 - 16
        local iconRenderY = sysRoomShape.y + sysRoomShape.h//2 - 16

        -- loop through the systems in the room
        for i, sysId in ipairs(sysTable) do
            local n = ((i-1)%maxIcons + 1)
            local currentPage = math.ceil(i/maxIcons)
            local display = ((math.floor(roomPreviewTimer)%pages) + 1) == currentPage
            if display then
                local iconRenderOffsetX = 0
                local iconRenderOffsetY = 0
                if currentIcons == maxIcons then
                    -- 2+ x 1 rooms
                    if roomSize == 2 and n == 2 then
                        iconRenderOffsetX = -1 * iconOffset
                    elseif roomSize == 2 and n == 3 then
                        iconRenderOffsetX = iconOffset
                    -- 1 x 2+ rooms
                    elseif roomSize == 3 and n == 2 then
                        iconRenderOffsetY = -1 * iconOffset
                    elseif roomSize == 3 and n == 3 then
                        iconRenderOffsetY = iconOffset
                    -- 2+ x 2+ rooms
                    elseif roomSize == 4 and n == 1 then
                        iconRenderOffsetX = -0.5 * iconOffset
                        iconRenderOffsetY = -0.5 * iconOffset
                    elseif roomSize == 4 and n == 2 then
                        iconRenderOffsetX = 0.5 * iconOffset
                        iconRenderOffsetY = -0.5 * iconOffset
                    elseif roomSize == 4 and n == 3 then
                        iconRenderOffsetX = -0.5 * iconOffset
                        iconRenderOffsetY = 0.5 * iconOffset
                    elseif roomSize == 4 and n == 4 then
                        iconRenderOffsetX = 0.5 * iconOffset
                        iconRenderOffsetY = 0.5 * iconOffset
                    end
                elseif currentIcons == maxIcons - 1 then
                    -- 2+ x 1 rooms
                    if roomSize == 2 and n == 1 then
                        iconRenderOffsetX = -0.5 * iconOffset
                    elseif roomSize == 2 and n == 2 then
                        iconRenderOffsetX = 0.5 * iconOffset
                    -- 1 x 2+ rooms
                    elseif roomSize == 3 and n == 1 then
                        iconRenderOffsetY = -0.5 * iconOffset
                    elseif roomSize == 3 and n == 2 then
                        iconRenderOffsetY = 0.5 * iconOffset
                    -- 2+ x 2+ rooms
                    elseif roomSize == 4 and n == 2 then
                        iconRenderOffsetX = -1 * iconOffset
                    elseif roomSize == 4 and n == 3 then
                        iconRenderOffsetX = iconOffset
                    end
                elseif currentIcons == maxIcons - 2 and roomSize == 4 then
                    -- 2+ x 2+ rooms
                    if n == 1 then
                        iconRenderOffsetX = -0.5 * iconOffset
                    elseif n == 2 then
                        iconRenderOffsetX = 0.5 * iconOffset
                    end
                end
                Graphics.CSurface.GL_PushMatrix()
                Graphics.CSurface.GL_Translate(iconRenderX + iconRenderOffsetX, iconRenderY + iconRenderOffsetY)
                Graphics.CSurface.GL_RenderPrimitive(systemIcons[sysId])
                Graphics.CSurface.GL_PopMatrix()
            end
        end
    end

    script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function() end, function(ship)
        if not Hyperspace.App.world.bStartedGame then
            local shipManager = Hyperspace.ships(ship.iShipId)
            local sysInfo = shipManager.myBlueprint.systemInfo
            local roomSystems = {}

            for key in vter(sysInfo:keys()) do
                if key ~= 11 then
                    if roomSystems[sysInfo[key].location[0]] then
                        table.insert(roomSystems[sysInfo[key].location[0]], key)
                    else
                        roomSystems[sysInfo[key].location[0]] = {key}
                    end
                end
            end

            roomPreviewTimer = roomPreviewTimer + time_increment(true)
            if roomPreviewTimer > mods.multiverse.INT_MAX then roomPreviewTimer = 0 end
            for roomId, sysTable in pairs(roomSystems) do
                render_system_icon(sysTable, roomId, shipManager)
            end
        end
    end)
end

--[[
////////////////////
NEGATIVE POWER WEAPON FIX
////////////////////
]]--
-- Make negative power weapons and other weapons which are powered only by negative power weapons
-- fire normally while the weapon system isn't powered.

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if ship:HasSystem(3) and not ship.weaponSystem:Powered() then
        local bonusPowerValue = 0
        for i = 0, ship.weaponSystem.weapons:size() - 1 do
            local weapon = ship.weaponSystem.weapons[i]
            if weapon.blueprint.power > 0 and bonusPowerValue >= weapon.blueprint.power then
                bonusPowerValue = math.max(0, bonusPowerValue - weapon.blueprint.power)
                push_projectiles_to_world(weapon)
            elseif weapon.blueprint.power < 0 then
                bonusPowerValue = bonusPowerValue - weapon.blueprint.power
                push_projectiles_to_world(weapon)
            end
        end
    end
end)

--[[
////////////////////
STARMAP BACKGROUND REGENERATION
////////////////////
]]--
-- Regenerate the starmap backgrounds on restart or on switching sectors

local oldWorldLevel = 0
local starmapBasicBackground = {}
do
    local tex = Hyperspace.Resources:GetImageId("map/zone_1.png")
    starmapBasicBackground[0] = Graphics.CSurface.GL_CreateImagePrimitive(tex, 0, 0, tex.width, tex.height, 0, Graphics.GL_Color(1, 1, 1, 1))
    local tex2 = Hyperspace.Resources:GetImageId("map/zone_2.png")
    starmapBasicBackground[1] = Graphics.CSurface.GL_CreateImagePrimitive(tex2, 0, 0, tex2.width, tex2.height, 0, Graphics.GL_Color(1, 1, 1, 1))
    local tex3 = Hyperspace.Resources:GetImageId("map/zone_3.png")
    starmapBasicBackground[2] = Graphics.CSurface.GL_CreateImagePrimitive(tex3, 0, 0, tex3.width, tex3.height, 0, Graphics.GL_Color(1, 1, 1, 1))
end

local function regenerate_starmap_backgrounds()
    local starMap = Hyperspace.App.world.starMap
    for i = 0, 2 do
        starMap.mapsBottom[i] = starmapBasicBackground[i]
    end
end

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function()
    local starMap = Hyperspace.App.world.starMap
    if starMap.worldLevel ~= oldWorldLevel then
        regenerate_starmap_backgrounds()
        oldWorldLevel = starMap.worldLevel
    end
end)

script.on_game_event("START_BEACON", false, regenerate_starmap_backgrounds)
