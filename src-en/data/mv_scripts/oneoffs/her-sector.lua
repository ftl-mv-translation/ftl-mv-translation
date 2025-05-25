--[[
////////////////////
INITIALIZATION
////////////////////
]]--

local vter = mods.multiverse.vter
local background_tint = mods.multiverse.background_tint
local on_load_game = mods.multiverse.on_load_game

local LEFT_SMILE_POINT = Hyperspace.Pointf(0, 300) --Leftmost point of the smile
local RIGHT_SMILE_POINT = Hyperspace.Pointf(650, 300) --Rightmost point of the smile, exit location
local SMILE_DIP = 150 --How far down the lowest point of the smile is
local Y_VARIATION = 10 --Smile points will be shifted up/down in an alternating manner by this amount

local EYE_RADIUS = 40 --Radius of an eye
local EYE_CENTER_1 = Hyperspace.Pointf(225, 100) --Center position of one eye
local EYE_CENTER_2 = Hyperspace.Pointf(425, 100) --Center position of the other eye
local POINTS_PER_EYE = 5 --How many points are used per eye

local herStarBackground
do
    local tex = Hyperspace.Resources:GetImageId("map/zone_her.png")
    herStarBackground = Graphics.CSurface.GL_CreateImagePrimitive(tex, 0, 0, tex.width, tex.height, 0, Graphics.GL_Color(1, 1, 1, 1))
end

local herBackground = Hyperspace.Animations:GetAnimation("her_vhs")
herBackground.tracker.loop = true
herBackground:Start(false)

--[[
////////////////////
LOGIC
////////////////////
]]--

local function vector_contains(vec, val)
    for member in vter(vec) do
        if member == val then return true end
    end
    return false
end
local function connect_locations(loc1, loc2)
    if loc1 == loc2 then return end
    if not vector_contains(loc1.connectedLocations, loc2) then
        loc1.connectedLocations:push_back(loc2)
    end

    if not vector_contains(loc2.connectedLocations, loc1) then
        loc2.connectedLocations:push_back(loc1)
    end
end
local function clear_connections(locationTable)
    for _, loc in ipairs(locationTable) do
        loc.connectedLocations:clear()
    end
end

local function calculate_parabola_constants(p1, p2, p3)
    local A_1 = -p1.x ^ 2 + p2.x ^ 2
    local B_1 = -p1.x + p2.x
    local C_1 = -p1.y + p2.y

    local A_2 = -p2.x ^ 2 + p3.x ^ 2
    local B_2 = -p2.x + p3.x
    local C_2 = -p2.y + p3.y

    local B_R = -B_2 / B_1
    local A_3 = B_R * A_1 + A_2
    local C_3 = B_R * C_1 + C_2

    local a = C_3 / A_3
    local b = (C_1 - A_1 * a) / B_1
    local c = p1.y - a * p1.x ^ 2 - b * p1.x
    return a, b, c
end

local function generate_grin(locationTable, leftPoint, rightPoint, dip, yVariation)
    local centerPoint = Hyperspace.Pointf((rightPoint.x + leftPoint.x) / 2, ((rightPoint.y + leftPoint.y) / 2) + dip)
    local a, b, c = calculate_parabola_constants(leftPoint, centerPoint, rightPoint)
    clear_connections(locationTable)
    for i = 1, #locationTable do
        local loc1 = locationTable[i]
        for j = i + 1, math.min(#locationTable, i + 2) do
            connect_locations(loc1, locationTable[j])
        end
        local rightwardProgress = (i - 1) / (#locationTable - 1)
        local x = leftPoint.x + (rightPoint.x - leftPoint.x) * rightwardProgress
        loc1.loc.x = x 
        loc1.loc.y = a * x ^ 2 + b * x + c + ((-1) ^ i * yVariation)
    end
end

local function generate_eye(locationTable, center, radius)
    clear_connections(locationTable)

    for i = 1, #locationTable do
        for j = i + 1, #locationTable do
           connect_locations(locationTable[i], locationTable[j])
        end
        local theta = math.pi * 2 * i / #locationTable
        local offset = Hyperspace.Pointf(radius * math.cos(theta), radius * math.sin(theta))
        locationTable[i].loc = center + offset
        locationTable[i].dangerZone = true
    end
end

local function generate_eyes(locationTable, radius, center1, center2)
    local halfwayIdx = #locationTable // 2
    local eye1Points = {}
    local eye2Points = {}
    for i = 1, halfwayIdx do
        table.insert(eye1Points, locationTable[i])
    end

    for i = halfwayIdx + 1, #locationTable do
        table.insert(eye2Points, locationTable[i])
    end

    generate_eye(eye1Points, center1, radius)
    generate_eye(eye2Points, center2, radius)
end

local function smile()
    local starMap = Hyperspace.App.world.starMap
    local locations = starMap.locations

    local grinLocs = {}
    local eyeLocs = {}

    Hyperspace.playerVariables.loc_sector_her = 1
    local eyeLocRequirement = POINTS_PER_EYE * 2

    local grinEnd
    for loc in vter(locations) do
        if loc.event.eventName == "REALM_MADNESS_START" then
            table.insert(grinLocs, 1, loc)
        elseif loc.event.eventName == "HER_FIGHT" then
            grinEnd = loc
        elseif eyeLocRequirement <= 0 or loc.event.eventName ~= "VISION_ENCOUNTER" then --Appended events should be reachable
            table.insert(grinLocs, loc)
        else
            table.insert(eyeLocs, loc)
            eyeLocRequirement = eyeLocRequirement - 1
        end
    end
    table.insert(grinLocs, grinEnd)

    generate_grin(grinLocs, LEFT_SMILE_POINT, RIGHT_SMILE_POINT, SMILE_DIP, Y_VARIATION)
    generate_eyes(eyeLocs, EYE_RADIUS, EYE_CENTER_1, EYE_CENTER_2)

    starMap.mapsBottom[starMap.worldLevel % 3] = herStarBackground
end
script.on_game_event("REALM_MADNESS_START", false, smile)

-- save/load handling
on_load_game(function()
    if Hyperspace.playerVariables.loc_sector_her > 0 then smile() end
end)

-- Animated background
script.on_render_event(Defines.RenderEvents.LAYER_BACKGROUND, function() end, function()
    if Hyperspace.playerVariables.loc_sector_her > 0 then herBackground:OnRender(1.0, background_tint(), false) end
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if Hyperspace.playerVariables.loc_sector_her > 0 then herBackground:Update() end
end)

-- disable the animated background for the her fight, the rest of the sector logic does not matter anymore
script.on_game_event("HER_FIGHT", false, function() Hyperspace.playerVariables.loc_sector_her = 0 end)
