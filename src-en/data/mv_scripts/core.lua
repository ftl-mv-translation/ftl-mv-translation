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

-- Update print position
Hyperspace.PrintHelper.GetInstance().x = 150

--[[
////////////////////
UTILITY FUNCTIONS
////////////////////
]]--

-- Convert a number to its sign (-1 for negatives, 1 for positives or 0).
function mods.multiverse.sign(n)
    return n > 0 and 1 or (n == 0 and 0 or -1)
end
local sign = mods.multiverse.sign

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
        Hyperspace.Global.GetInstance():GetCApp().world.space.projectiles:push_back(projectile)
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

local systemIcons = {}
do
    local function systemIcon(name)
        local tex = Hyperspace.Resources:GetImageId("icons/s_"..name.."_overlay.png")
        return Graphics.CSurface.GL_CreateImagePrimitive(tex, 0, 0, 32, 32, 0, Graphics.GL_Color(1, 1, 1, 0.5))
    end
    for id, sys in pairs(mods.multiverse.systemIds) do
        systemIcons[id] = systemIcon(sys)
    end
end
script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function() end, function(ship)
    if not Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
        local shipManager = Hyperspace.Global.GetInstance():GetShipManager(ship.iShipId)
        local sysInfo = shipManager.myBlueprint.systemInfo
        local medCloneSameRoom = sysInfo:has_key(5) and sysInfo:has_key(13) and sysInfo[5].location[0] == sysInfo[13].location[0]
        for sysId = 0, 15 do -- Skip temporal
            if sysId ~= 11 then -- Skip artillery
            
                -- Special logic for medbay and clonebay
                local medicalException = false
                local skipBackground = false
                local iconRenderOffsetX = 0
                local iconRenderOffsetY = 0
                if (sysId == 5 or sysId == 13) and medCloneSameRoom then
                    if not (shipManager:HasSystem(5) or shipManager:HasSystem(13)) then
                        local sysRoomShape = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetRoomShape(sysInfo[sysId].location[0])
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
                
                -- Render the icons
                if not medicalException and not shipManager:HasSystem(sysId) and sysInfo:has_key(sysId) then
                    local sysRoomShape = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetRoomShape(sysInfo[sysId].location[0])
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
        end
    end
    return Defines.Chain.CONTINUE
end)

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

--[[
////////////////////
PRO-HULL BEAM FIX
////////////////////
]]--
-- Allow the pro-hull beam to be visible while also repairing hull.

mods.multiverse.beamDamageMods = {}
local beamDamageMods = mods.multiverse.beamDamageMods
beamDamageMods["BEAM_REPAIR"] = {iDamage = -2}

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    local damageMods = beamDamageMods[projectile.extend.name]
    if damageMods then
        for damageType, value in pairs(damageMods) do
            damage[damageType] = value
        end
    end
    return Defines.Chain.CONTINUE, beamHitType
end)
