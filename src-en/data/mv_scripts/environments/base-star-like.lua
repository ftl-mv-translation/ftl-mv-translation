--[[
////////////////////
INITIALIZATION
////////////////////
]]--

local check_paused = mods.multiverse.check_paused
local time_increment = mods.multiverse.time_increment
local vter = mods.multiverse.vter
local register_environment = mods.multiverse.register_environment
local on_load_game = mods.multiverse.on_load_game

-- Storing data for all star-like hazards
mods.multiverse.environmentDataStar = {}
local environmentDataStar = mods.multiverse.environmentDataStar

-- Register everything associated with the hazard
function mods.multiverse.register_environment_star(name, varName, varNameRequeue, icon, sound, locationText, triggeredEvent, queueEvent, flashTime, flashDelay, surgeFunction)
    -- Register the hazard icon
    register_environment(name, varName, icon)

    -- Save star data
    environmentDataStar[name] = {
        varName = varName,
        varNameRequeue = varNameRequeue,
        sound = sound,
        locationText = locationText,
        triggeredEvent = triggeredEvent,
        queueEvent = queueEvent,
        flashTime = flashTime,
        flashDelay = flashDelay,
        flashTimeCurrent = 0,
        flashTimePrevious = 0,
        surgeFunction = surgeFunction
    }
end

-- Check if a location is a hazard
local function is_star_location(event, hazardName)
    local customEvent = Hyperspace.CustomEventsParser.GetInstance():GetCustomEvent(event.eventName)
    if not customEvent then return false end
    for triggeredEventId in vter(customEvent.triggeredEvents) do
        if Hyperspace.TriggeredEventDefinition.defs[triggeredEventId].event == environmentDataStar[hazardName].triggeredEvent then
            return true
        end
    end
    return false
end

-- Define sig figs to save for pulse timer for save-scum prevention
local flashTimeSavePrecision = 100

--[[
////////////////////
LOGIC
////////////////////
]]--

-- Reset variables on jump
script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function()
    for _, envData in pairs(environmentDataStar) do
        Hyperspace.playerVariables[envData.varName] = 0
        Hyperspace.playerVariables.loc_hazard_pulse_timer = 0
        envData.flashTimeCurrent = 0
        envData.flashTimePrevious = 0
    end
end)

-- Activate the hazard when an event with its triggered event happens,
-- and deactivate it when we go to a beacon that doesn't have it
script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
    for envName, envData in pairs(environmentDataStar) do
        if is_star_location(event, envName) then
            Hyperspace.playerVariables[envData.varName] = 1
            Hyperspace.App.world.space:SwitchPlanet("NONE")

            -- Mark event for re-queuing hazard on revisit to this beacon
            if Hyperspace.App.world.starMap.currentLoc.visited > 1 and Hyperspace.App.world.starMap.currentLoc.event.eventName == event.eventName then
                Hyperspace.playerVariables[envData.varNameRequeue] = 1
            end
        elseif Hyperspace.App.world.starMap.currentLoc.event.eventName == event.eventName then
            Hyperspace.playerVariables[envData.varName] = 0
            Hyperspace.playerVariables.loc_hazard_pulse_timer = 0
            envData.flashTimeCurrent = 0
            envData.flashTimePrevious = 0
        end
    end
end)

-- Re-queue hazard when unpaused if marked
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    for _, envData in pairs(environmentDataStar) do
        if not check_paused() and Hyperspace.playerVariables[envData.varNameRequeue] > 0 then
            Hyperspace.playerVariables[envData.varNameRequeue] = 0
            Hyperspace.CustomEventsParser.GetInstance():LoadEvent(Hyperspace.App.world, envData.queueEvent, false, -1)
        end
    end
end)

-- Keep danger while at hazard
script.on_internal_event(Defines.InternalEvents.DANGEROUS_ENVIRONMENT, function()
    for _, envData in pairs(environmentDataStar) do
        if Hyperspace.playerVariables[envData.varName] > 0 then
            return true
        end
    end
end)

-- Start the hazard pulse
script.on_load(function()
    for _, envData in pairs(environmentDataStar) do
        script.on_game_event(envData.triggeredEvent, false, function()
            Hyperspace.Sounds:PlaySoundMix(envData.sound, -1, false)
            envData.flashTimeCurrent = envData.flashTime + envData.flashDelay
        end)
    end
end)

-- Manage flash timer
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    for _, envData in pairs(environmentDataStar) do
        if Hyperspace.playerVariables[envData.varName] > 0 and envData.flashTimeCurrent > 0 and not check_paused() then
            envData.flashTimeCurrent = math.max(envData.flashTimeCurrent - time_increment(), 0)
            -- Keep timer stored in a player variable so we can load it to prevent
            -- save-scumming out of being slammed by hazard pulse
            Hyperspace.playerVariables.loc_hazard_pulse_timer = math.ceil(envData.flashTimeCurrent*flashTimeSavePrecision)
            local halfTime = envData.flashTime/2
            if envData.flashTimeCurrent < halfTime and envData.flashTimePrevious >= halfTime then
                if Hyperspace.ships.player then envData.surgeFunction(Hyperspace.ships.player) end
                if Hyperspace.ships.enemy then envData.surgeFunction(Hyperspace.ships.enemy) end
            end
            envData.flashTimePrevious = envData.flashTimeCurrent
        end
    end
end)

-- Load flash timer in case the player saved mid-flare
on_load_game(function()
    for _, envData in pairs(environmentDataStar) do
        if Hyperspace.playerVariables[envData.varName] > 0 then
            Hyperspace.App.world.space:SwitchPlanet("NONE")
            envData.flashTimeCurrent = Hyperspace.playerVariables.loc_hazard_pulse_timer/flashTimeSavePrecision
            envData.flashTimePrevious = envData.flashTimeCurrent
            return -- Should only ever be one custom star-like hazard at a location
        end
    end
end)

-- Show hazard label at hazard beacons
script.on_internal_event(Defines.InternalEvents.GET_BEACON_HAZARD, function(location)
    for envName, envData in pairs(environmentDataStar) do
        if is_star_location(location.event, envName) then
            return Hyperspace.Text:GetText(envData.locationText)
        end
    end
end)
