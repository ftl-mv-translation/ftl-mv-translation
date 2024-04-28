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

-- Check if one string starts with another string
function mods.multiverse.string_starts(str, start)
    return string.sub(str, 1, string.len(start)) == start
end
local string_starts = mods.multiverse.string_starts

-- Get a table for a userdata value by a given name.
-- Useful for distinguishing tables with namespaces for compatibility with other mods.
function mods.multiverse.userdata_table(userdata, tableName)
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
end
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
function mods.multiverse.resists_mind_control(crewmem)
    do
        local _, telepathic = crewmem.extend:CalculateStat(Hyperspace.CrewStat.IS_TELEPATHIC)
        if telepathic then return true end
    end
    do
        local _, resistMc = crewmem.extend:CalculateStat(Hyperspace.CrewStat.RESISTS_MIND_CONTROL)
        if resistMc then return true end
    end
    return false
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
    return drone
end
local spawn_temp_drone = mods.multiverse.spawn_temp_drone

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

-- List of ships to show preview for temporal system on
mods.multiverse.temporalPreviewShips = {}
local temporalPreviewShips = mods.multiverse.temporalPreviewShips
do
    -- Collect system icons
    local systemIcons = {}
    local function system_icon(name)
        local tex = Hyperspace.Resources:GetImageId("icons/s_"..name.."_overlay.png")
        return Graphics.CSurface.GL_CreateImagePrimitive(tex, 0, 0, 32, 32, 0, Graphics.GL_Color(1, 1, 1, 0.5))
    end
    for id, sys in pairs(mods.multiverse.systemIds) do
        systemIcons[id] = system_icon(sys)
    end
    
    -- Render icons
    local function render_icon(sysId, ship, sysInfo, medCloneSameRoom)
        -- Special logic for medbay and clonebay
        local medicalException = false
        local skipBackground = false
        local iconRenderOffsetX = 0
        local iconRenderOffsetY = 0
        if (sysId == 5 or sysId == 13) and medCloneSameRoom then
            if not (ship:HasSystem(5) or ship:HasSystem(13)) then
                local sysRoomShape = Hyperspace.ShipGraph.GetShipInfo(ship.iShipId):GetRoomShape(sysInfo[sysId].location[0])
                if sysRoomShape.w > 35 then
                    if sysId == 5 then
                        iconRenderOffsetX = -16
                    else
                        iconRenderOffsetX = 16
                        skipBackground = true
                    end
                else
                    if sysId == 5 then
                        iconRenderOffsetY = -16
                    else
                        iconRenderOffsetY = 16
                        skipBackground = true
                    end
                end
            else
                medicalException = true
            end
        end
        
        -- Render logic
        if not medicalException and not ship:HasSystem(sysId) and sysInfo:has_key(sysId) then
            local sysRoomShape = Hyperspace.ShipGraph.GetShipInfo(ship.iShipId):GetRoomShape(sysInfo[sysId].location[0])
            local iconRenderX = sysRoomShape.x + sysRoomShape.w//2 - 16 + iconRenderOffsetX
            local iconRenderY = sysRoomShape.y + sysRoomShape.h//2 - 16 + iconRenderOffsetY
            if not skipBackground then
                local outlineSize = 2
                Graphics.CSurface.GL_DrawRect(
                    sysRoomShape.x,
                    sysRoomShape.y,
                    sysRoomShape.w,
                    sysRoomShape.h,
                    Graphics.GL_Color(0, 0, 0, 0.3))
                Graphics.CSurface.GL_DrawRectOutline(
                    sysRoomShape.x + outlineSize,
                    sysRoomShape.y + outlineSize,
                    sysRoomShape.w - 2*outlineSize,
                    sysRoomShape.h - 2*outlineSize,
                    Graphics.GL_Color(0.8, 0, 0, 0.5), outlineSize)
            end
            Graphics.CSurface.GL_PushMatrix()
            Graphics.CSurface.GL_Translate(iconRenderX, iconRenderY)
            Graphics.CSurface.GL_RenderPrimitive(systemIcons[sysId])
            Graphics.CSurface.GL_PopMatrix()
        end
    end
    script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function() end, function(ship)
        if not Hyperspace.App.world.bStartedGame then
            local shipManager = Hyperspace.ships(ship.iShipId)
            local sysInfo = shipManager.myBlueprint.systemInfo
            local medCloneSameRoom = sysInfo:has_key(5) and sysInfo:has_key(13) and sysInfo[5].location[0] == sysInfo[13].location[0]
            for sysId = 0, 10 do
                render_icon(sysId, shipManager, sysInfo, medCloneSameRoom)
            end
            -- Skip artillery (system ID 11)
            for sysId = 12, 15 do
                render_icon(sysId, shipManager, sysInfo, medCloneSameRoom)
            end
            -- Only render temporal if the current ship is an exception
            if (temporalPreviewShips[shipManager.myBlueprint.blueprintName]) then
                render_icon(20, shipManager, sysInfo, medCloneSameRoom)
            end
        end
        return Defines.Chain.CONTINUE
    end)
end

--[[
////////////////////
NEGATIVE POWER WEAPON FIX
////////////////////
]]--
-- Make negetive power weapons and other weapons which are powered only by negetive power weapons
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
