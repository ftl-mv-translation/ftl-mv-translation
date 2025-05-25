--[[
////////////////////
INITIALIZATION
////////////////////
]]--

local lerp = mods.multiverse.lerp
local alpha_pulse = mods.multiverse.alpha_pulse
local background_tint = mods.multiverse.background_tint
local check_paused = mods.multiverse.check_paused
local time_increment = mods.multiverse.time_increment
local vter = mods.multiverse.vter
local environmentDataStar = mods.multiverse.environmentDataStar
local register_environment_star = mods.multiverse.register_environment_star

-- Rad stat boosts need to be duplicated since StatBoostDefinition::savedStatBoostDefs isn't properly exposed
local radMove = Hyperspace.StatBoostDefinition()
radMove.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
radMove.stat = Hyperspace.CrewStat.MOVE_SPEED_MULTIPLIER
radMove.boostType = Hyperspace.StatBoostDefinition.BoostType.MULT
radMove.amount = 0.33
radMove.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
radMove.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
radMove.droneTarget = Hyperspace.StatBoostDefinition.DroneTarget.CREW
radMove.affectsSelf = true
radMove.maxStacks = 1
radMove.duration = 10
radMove.boostAnim = "bio_poison"
radMove.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
radMove.stackId = radMove.realBoostId
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(radMove)

local radStun = Hyperspace.StatBoostDefinition()
radStun.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
radStun.stat = Hyperspace.CrewStat.STUN_MULTIPLIER
radStun.boostType = Hyperspace.StatBoostDefinition.BoostType.MULT
radStun.amount = 1.75
radStun.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
radStun.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
radStun.droneTarget = Hyperspace.StatBoostDefinition.DroneTarget.CREW
radStun.affectsSelf = true
radStun.maxStacks = 1
radStun.duration = 10
radStun.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
radStun.stackId = radStun.realBoostId
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(radStun)

local radRepair = Hyperspace.StatBoostDefinition()
radRepair.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
radRepair.stat = Hyperspace.CrewStat.REPAIR_SPEED_MULTIPLIER
radRepair.boostType = Hyperspace.StatBoostDefinition.BoostType.MULT
radRepair.amount = 0.33
radRepair.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
radRepair.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
radRepair.droneTarget = Hyperspace.StatBoostDefinition.DroneTarget.CREW
radRepair.affectsSelf = true
radRepair.maxStacks = 1
radRepair.duration = 10
radRepair.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
radRepair.stackId = radRepair.realBoostId
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(radRepair)

-- Start fires, irradiate crew and deal damage
local function do_blue_giant_flare(ship)
    if not (ship.bDestroyed or ship.bJumping) then
        -- Target 1-3 rooms if shields are up, 2-4 rooms if shields are down
        for fireCounter = 1, ((ship:GetShieldPower().first < 1) and math.random(2, 4) or math.random(1, 3)) do
            local targetRoom = math.random(0, ship.ship.vRoomList:size() - 1)
            ship:StartFire(targetRoom)
            for crew in vter(ship.vCrewList) do
                if not crew:IsDrone() and crew.iRoomId == targetRoom then
                    Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(radMove), crew)
                    Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(radStun), crew)
                    Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(radRepair), crew)
                end
            end

            -- 50% chance for damage in each room targeted
            if (math.random(1, 2) == 1) then
                local damage = Hyperspace.Damage()
                damage.iDamage = 1
                ship:DamageArea(ship:GetRoomCenter(targetRoom), damage, true)
            end
        end
    end
end

-- Register the hazard
register_environment_star("blue_giant", "loc_environment_blue_giant", "loc_blue_giant_requeue", "warnings/danger_star_blue.png", "solarFlare", "map_blue_giant_loc", "BLUE_GIANT_FLARE", "BLUE_GIANT_FLARE_QUEUE", 1, 0.5, do_blue_giant_flare)
local envData = environmentDataStar.blue_giant

-- Load assets
local blueGiant
local blueGiantGlow
do
    local tex = Hyperspace.Resources:GetImageId("stars/planet_sun_bluegiant1.png")
    blueGiant = Graphics.CSurface.GL_CreateImagePrimitive(tex, -tex.width/2, -tex.width/2, tex.width, tex.height, 0, Graphics.GL_Color(1, 1, 1, 1))
    tex = Hyperspace.Resources:GetImageId("stars/planet_sun_bluegiant2.png")
    blueGiantGlow = Graphics.CSurface.GL_CreateImagePrimitive(tex, -tex.width/2, -tex.width/2, tex.width, tex.height, 0, Graphics.GL_Color(1, 1, 1, 1))
end

-- Pulse timers
local bottomPulseTime = 7
local bottomPulseTimeCurrent = 0
local mainPulseTime = 5
local mainPulseTimeCurrent = 0
local topPulseTime = 10
local topPulseTimeCurrent = 0

--[[
////////////////////
VISUALS
////////////////////
]]--

-- Progress pulse timers
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if Hyperspace.playerVariables.loc_environment_blue_giant > 0 then
        if not (check_paused() or Hyperspace.Settings.lowend) then
            bottomPulseTimeCurrent = bottomPulseTimeCurrent + time_increment()
            if bottomPulseTimeCurrent > bottomPulseTime then
                bottomPulseTimeCurrent = bottomPulseTimeCurrent - bottomPulseTime
            end
            mainPulseTimeCurrent = mainPulseTimeCurrent + time_increment()
            if mainPulseTimeCurrent > mainPulseTime then
                mainPulseTimeCurrent = mainPulseTimeCurrent - mainPulseTime
            end
            topPulseTimeCurrent = topPulseTimeCurrent + time_increment()
            if topPulseTimeCurrent > topPulseTime then
                topPulseTimeCurrent = topPulseTimeCurrent - topPulseTime
            end
        end
    end
end)

-- Render blue giant
script.on_render_event(Defines.RenderEvents.LAYER_FOREGROUND, function()
    if Hyperspace.playerVariables.loc_environment_blue_giant > 0 and not Hyperspace.App.world.space.bNebula then
        Graphics.CSurface.GL_PushMatrix()
        Graphics.CSurface.GL_Translate(570, 820)

        local tint = background_tint()
        if Hyperspace.Settings.lowend then
            Graphics.CSurface.GL_RenderPrimitiveWithColor(blueGiant, tint)
        else
            tint.a = 0.1 + 0.9*alpha_pulse(bottomPulseTime, bottomPulseTimeCurrent)
            Graphics.CSurface.GL_RenderPrimitiveWithColor(blueGiantGlow, tint)
            tint.a = 0.7 + 0.3*alpha_pulse(mainPulseTime, mainPulseTimeCurrent)
            Graphics.CSurface.GL_RenderPrimitiveWithColor(blueGiant, tint)
            tint.a = 0.05 + 0.35*alpha_pulse(topPulseTime, topPulseTimeCurrent)
            Graphics.CSurface.GL_RenderPrimitiveWithColor(blueGiantGlow, tint)
        end

        Graphics.CSurface.GL_PopMatrix()
    end
end, function() end)

-- Show flash for solar flare
script.on_internal_event(Defines.InternalEvents.GET_HAZARD_FLASH, function()
    if Hyperspace.playerVariables.loc_environment_blue_giant > 0 and envData.flashTimeCurrent > 0 and envData.flashTimeCurrent <= envData.flashTime then
        local alpha = alpha_pulse(envData.flashTime, envData.flashTimeCurrent)
        return lerp(0, 1, alpha), 1, 1, alpha
    end
end)
