local vter = mods.multiverse.vter
local get_distance = mods.multiverse.get_distance
local on_load_game = mods.multiverse.on_load_game

local function eliminate_deadends()
    for loc in vter(Hyperspace.App.world.starMap.locations) do
        -- Check if this location can only be reached through a 1-beacon passage
        if loc.connectedLocations:size() == 1 and loc.connectedLocations[0].connectedLocations:size() == 2 then
            -- Find the closest location that isn't this location or the
            -- one that's already connected and form a connection with it
            local closestLoc = nil
            local closestLocDist = mods.multiverse.INT_MAX
            for locOther in vter(Hyperspace.App.world.starMap.locations) do
                if locOther ~= loc and locOther ~= loc.connectedLocations[0] then
                    local dist = get_distance(locOther.loc, loc.loc)
                    if dist < closestLocDist then
                        closestLoc = locOther
                        closestLocDist = dist
                    end
                end
            end
            if closestLoc then
                loc.connectedLocations:push_back(closestLoc)
                closestLoc.connectedLocations:push_back(loc)
            end
        end
    end
end

local startEvents = {}
do
    local doc = RapidXML.xml_document("data/sector_data.xml")
    local root = doc:first_node("FTL") or doc
    local sectorNode = root:first_node("sectorDescription")
    while sectorNode do
        local startEventNode = sectorNode:first_node("startEvent")
        if startEventNode then startEvents[startEventNode:value()] = true end
        sectorNode = sectorNode:next_sibling("sectorDescription")
    end
    doc:clear()
end
for startEvent, _ in pairs(startEvents) do
    script.on_game_event(startEvent, false, eliminate_deadends)
end
on_load_game(eliminate_deadends)
