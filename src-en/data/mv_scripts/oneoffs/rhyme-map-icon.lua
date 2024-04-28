--[[
////////////////////
UTIL
////////////////////
]]--

local time_increment = mods.multiverse.time_increment
local string_starts = mods.multiverse.string_starts

local function map_ship_primitive(dir, xPos, yPos)
    local tex = Hyperspace.Resources:GetImageId(dir)
    local ret = Hyperspace.Resources:CreateImagePrimitive(tex, xPos or -10, yPos or -tex.height/2, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
    ret.textureAntialias = true
    return ret
end

--[[
////////////////////
LOGIC
////////////////////
]]--

local animCount = 4
local animSpeed = 6 --FPS
local animTimer = 0

local rhymeIcons = {}
for i = 1, animCount do rhymeIcons[i] = map_ship_primitive("map/map_icon_mup_rhyme_frame"..i..".png") end

local rhymeIconsFuel = {}
for i = 1, animCount do rhymeIconsFuel[i] = map_ship_primitive("map/map_icon_mup_rhyme_fuel_frame"..i..".png") end

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local shouldRun = Hyperspace.App.world.bStartedGame and
                      Hyperspace.ships.player and
                      string_starts(Hyperspace.ships.player.myBlueprint.blueprintName, "PLAYER_SHIP_RHYME")
    if not shouldRun then return end
    animTimer = (animTimer + time_increment()) % (animCount/animSpeed)
    local frame = math.ceil(animTimer*animSpeed)
    local starMap = Hyperspace.App.world.starMap
    starMap.ship = rhymeIcons[frame]
    starMap.shipNoFuel = rhymeIconsFuel[frame]
end)
