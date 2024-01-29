--[[
////////////////////
IMPORTS
////////////////////
]]--
-- Make functions from the core script that we need to use in this script local

local reduce_weapon_charge = mods.multiverse.reduce_weapon_charge
local push_projectiles_to_world = mods.multiverse.push_projectiles_to_world
local is_first_shot = mods.multiverse.is_first_shot

--[[
////////////////////
WEAPON TAGS
////////////////////
]]--

-- Create a table of parsers to process custom weapon tags
local weaponTagParsers = {}

-- Conservative tag logic
local conservatives = {}
table.insert(weaponTagParsers, function(weaponNode)
    if weaponNode:first_node("mv-conservative") then
        conservatives[weaponNode:first_attribute("name"):value()] = true
    end
end)
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if ship:HasSystem(3) and not ship.weaponSystem:Powered() then
        local hasNegetivePowerWeapon = false
        for i = 0, ship.weaponSystem.weapons:size() - 1 do
            if ship.weaponSystem.weapons[i].blueprint.power < 0 then
                hasNegetivePowerWeapon = true
                break
            end
        end
        if hasNegetivePowerWeapon then
            for i = 0, ship.weaponSystem.weapons:size() - 1 do
                local weapon = ship.weaponSystem.weapons[i]
                if conservatives[weapon.blueprint.name] then
                    push_projectiles_to_world(weapon)
                end
            end
        else
            for i = 0, ship.weaponSystem.weapons:size() - 1 do
                local weapon = ship.weaponSystem.weapons[i]
                if conservatives[weapon.blueprint.name] then
                    reduce_weapon_charge(ship, weapon)
                end
            end
        end
    end
end)

-- Stealth tag logic
local stealthWeapons = {}
table.insert(weaponTagParsers, function(weaponNode)
    if weaponNode:first_node("mv-stealth") then
        stealthWeapons[weaponNode:first_attribute("name"):value()] = true
    end
end)
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    if stealthWeapons[weapon.blueprint.name] then
        local ship = Hyperspace.ships(weapon.iShipId)
        if ship:HasSystem(10) and ship.cloakSystem.bTurnedOn and ship:HasAugmentation("CLOAK_FIRE") == 0 and is_first_shot(weapon, true) then
            local timer = ship.cloakSystem.timer
            timer.currTime = timer.currTime - timer.currGoal/5
        end
    end
end)

-- Check all weapons for custom tags
for _, file in ipairs(mods.multiverse.blueprintFiles) do
    local doc = RapidXML.xml_document(file)
    local weaponNode = (doc:first_node("FTL") or doc):first_node("weaponBlueprint")
    while weaponNode do
        for _, weaponTagParser in ipairs(weaponTagParsers) do
            weaponTagParser(weaponNode)
        end
        weaponNode = weaponNode:next_sibling("weaponBlueprint")
    end
    doc:clear()
end

--[[
////////////////////
TAG FOR CUSTOM MAP ICONS
////////////////////
]]--

-- Utility functions
local function node_get_number_default(node, default)
    if not node then return default end
    local ret = tonumber(node:value())
    if not ret then return default end
    return ret
end
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
    local starMap = Hyperspace.Global.GetInstance():GetCApp().world.starMap
    starMap.ship = mapIconBase
    starMap.shipNoFuel = mapIconBaseFuel
end, 100)
script.on_internal_event(Defines.InternalEvents.ON_TICK, function() -- Set custom icon
    if not (setMapIcon and Hyperspace.ships.player) then return end
    setMapIcon = false
    local starMap = Hyperspace.Global.GetInstance():GetCApp().world.starMap
    local playerShipName = Hyperspace.ships.player.myBlueprint.blueprintName
    for iconShipName, icons in pairs(mapIcons) do
        if playerShipName == iconShipName then
            starMap.ship = icons.fuel
            starMap.shipNoFuel = icons.noFuel
            return
        end
    end
end)
