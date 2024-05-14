-- Utility functions
local node_get_number_default = mods.multiverse.node_get_number_default
local function map_ship_primitive(dir, xPos, yPos)
    local tex = Hyperspace.Resources:GetImageId(dir)
    local ret = Hyperspace.Resources:CreateImagePrimitive(tex, xPos or -10, yPos or -tex.height/2, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
    ret.textureAntialias = true
    return ret
end

-- Map icons setup
local mapIcons = {}
local mapIconBase = map_ship_primitive("map/map_icon_ship.png")
local mapIconBaseFuel = map_ship_primitive("map/map_icon_ship_fuel.png")

-- Read map icons from XML
do
    local iconCashe = {}
    for _, file in ipairs(mods.multiverse.blueprintFiles) do
        local doc = RapidXML.xml_document(file)
        local node = (doc:first_node("FTL") or doc):first_node("shipBlueprint")
        while node do
            local iconNode = node:first_node("mv-mapImage")
            if iconNode then
                local iconName = iconNode:value()
                if iconName ~= "" then
                    local shipName = node:first_attribute("name"):value()
                    log("Found mv-mapImage tag for ship "..shipName)
                    local icons = iconCashe[iconName]
                    if not icons then
                        if not pcall(function()
                            local offset = -10 + node_get_number_default(iconNode:first_attribute("offset"), 0)
                            icons = {
                                fuel = map_ship_primitive("map/"..iconName..".png", offset),
                                noFuel = map_ship_primitive("map/"..iconName.."_fuel.png", offset)
                            }
                        end) then
                            error("Error loading mv-mapImage for "..shipName.."!")
                        end
                        iconCashe[iconName] = icons
                    end
                    mapIcons[shipName] = icons
                end
            end
            node = node:next_sibling("shipBlueprint")
        end
        doc:clear()
    end
end

-- Apply map icons
local setMapIcon = false
script.on_init(function() setMapIcon = true end) -- Handle icon on game start
script.on_internal_event(Defines.InternalEvents.ON_TICK, function() -- Reset icon
    if not (setMapIcon and Hyperspace.ships.player) then return end
    local starMap = Hyperspace.App.world.starMap
    starMap.ship = mapIconBase
    starMap.shipNoFuel = mapIconBaseFuel
end, 100)
script.on_internal_event(Defines.InternalEvents.ON_TICK, function() -- Set custom icon
    if not (setMapIcon and Hyperspace.ships.player) then return end
    setMapIcon = false
    local starMap = Hyperspace.App.world.starMap
    local playerShipName = Hyperspace.ships.player.myBlueprint.blueprintName
    for iconShipName, icons in pairs(mapIcons) do
        if playerShipName == iconShipName then
            starMap.ship = icons.fuel
            starMap.shipNoFuel = icons.noFuel
            return
        end
    end
end)
