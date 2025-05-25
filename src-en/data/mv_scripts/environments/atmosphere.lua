--[[
////////////////////
INITIALIZATION
////////////////////
]]--

local register_environment = mods.multiverse.register_environment

mods.multiverse.atmoBackgrounds = {
    BACK_SECTOR_START = true,
    BACK_SECTOR_START_RED = true,
    BACK_EVENT_A55_CITY = true,
    BACKGROUND_ARCHIVE_SHIPYARDS = true,
    BACK_EVENT_CITYATTACK = true,
    BACK_EVENT_CLANJAIL = true,
    BACK_EVENT_COALBASE = true,
    BACK_EVENT_CONSTRUCTIONYARD = true,
    BACK_EVENT_CRYSTAL_CACHE = true,
    BACK_EVENT_CRYSTALCONSTRUCTION = true,
    BACKGROUND_EVENT_DEVORAKHIDEOUT = true,
    BACK_EVENT_DUSKCAP = true,
    BACKGROUND_EARTH = true,
    BACKGROUND_ELLIECITY = true,
    BACK_EVENT_EMBERCHURCH = true,
    BACK_EVENT_EVACCITY = true,
    BACK_EVENT_FOREST = true,
    BACK_EVENT_GARDENS = true,
    BACK_EVENT_HANGAR = true,
    BACK_EVENT_HEKTARHQ = true,
    BACK_EVENT_HEKTARSHIPYARD = true,
    BACK_EVENT_HIVE = true,
    BACK_EVENT_JERRYHOME = true,
    BACK_EVENT_LEECHCAP = true,
    BACK_EVENT_MEGATREE = true,
    BACK_EVENT_MEMORIAL = true,
    BACK_EVENT_NEST = true,
    BACK_EVENT_ORCHID_GARDEN = true,
    BACK_EVENT_ORCHIDFOREST = true,
    BACK_EVENT_OSMIA = true,
    BACK_EVENT_PHEROMONEFACTORY = true,
    BACKGROUND_PINNACLE_SHIPYARDS = true,
    BACK_EVENT_PONYWORLD = true,
    BACK_EVENT_POWERGRID = true,
    BACK_EVENT_REBELCITY = true,
    BACK_EVENT_REVCACHE = true,
    BACK_EVENT_ROCKHOME = true,
    BACK_EVENT_ROCKRAVINE = true,
    BACK_EVENT_SECRETLAB = true,
    BACK_EVENT_SLUG_PALACE = true,
    BACK_EVENT_SPACEYACHT = true,
    BACK_EVENT_SPIDERLAB = true,
    BACK_EVENT_TURBAN = true,
    BACK_EVENT_VAMP = true,
    BACK_SECTOR_JERRY = true,
    BACK_EVENT_ESTATE_HQ = true,
    BACK_EVENT_ESTATE_SHIPYARD = true,
    BACKGROUND_ZOLTHUB = true,
    BACK_EVENT_ZOLTAN_TEMPLE = true
}
local atmoBackgrounds = mods.multiverse.atmoBackgrounds

--[[
////////////////////
LOGIC
////////////////////
]]--

-- Register the hazard
register_environment("atmosphere", "loc_environment_atmosphere", "warnings/danger_atmo.png")

-- Reset variables on jump
script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function()
    Hyperspace.playerVariables.loc_environment_atmosphere = 0
end)

-- Track whether we've entered a location that has an atmosphere
script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
    if atmoBackgrounds[Hyperspace.App.world.starMap.currentLoc.spaceImage] then
        Hyperspace.playerVariables.loc_environment_atmosphere = 1
    elseif Hyperspace.App.world.starMap.currentLoc.event.eventName == event.eventName then
        Hyperspace.playerVariables.loc_environment_atmosphere = 0
    end
end)

-- Add oxygen instead of removing
script.on_internal_event(Defines.InternalEvents.CALCULATE_LEAK_MODIFIER, function(ship, mod)
    if Hyperspace.playerVariables.loc_environment_atmosphere > 0 then
        return Defines.Chain.CONTINUE, -mod
    end
end)
