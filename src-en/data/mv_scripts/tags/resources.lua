--[[
////////////////////
IMPORTS AND UTIL
////////////////////
]]--

-- Make functions from the core script that we need to use in this script local
local vter = mods.multiverse.vter
local reduce_weapon_charge = mods.multiverse.reduce_weapon_charge
local push_projectiles_to_world = mods.multiverse.push_projectiles_to_world
local is_first_shot = mods.multiverse.is_first_shot
local get_room_at_location = mods.multiverse.get_room_at_location
local get_adjacent_rooms = mods.multiverse.get_adjacent_rooms
local userdata_table = mods.multiverse.userdata_table
local resists_mind_control = mods.multiverse.resists_mind_control
local can_be_mind_controlled = mods.multiverse.can_be_mind_controlled
local get_ship_crew_point = mods.multiverse.get_ship_crew_point
local time_increment = mods.multiverse.time_increment
local spawn_temp_drone = mods.multiverse.spawn_temp_drone
local string_replace = mods.multiverse.string_replace
local cbwrap = mods.multiverse.cbwrap
local table_to_list_string = mods.multiverse.table_to_list_string

-- Make xml helper functions local
local node_child_iter = mods.multiverse.node_child_iter
local parse_xml_bool = mods.multiverse.parse_xml_bool
local node_get_bool_default = mods.multiverse.node_get_bool_default
local node_get_number_default = mods.multiverse.node_get_number_default

-- Make other helper functions local
local parse_damage_from_children = mods.multiverse.parse_damage_from_children
local damage_to_string = mods.multiverse.damage_to_string

-- Make tag tables local
local weaponTagParsers = mods.multiverse.weaponTagParsers
local droneTagParsers = mods.multiverse.droneTagParsers

-- Reset weapon charge to 0
local function reset_weapon_charge(weapon)
    weapon.cooldown.first = 0
    weapon.chargeLevel = 0
end

--[[
////////////////////
DATA & PARSER
////////////////////
]]--

local resourceWeapons = {}
table.insert(weaponTagParsers, function(weaponNode)
    local resourceNode = weaponNode:first_node("mv-resources")
    if resourceNode then
        resourceWeapons[weaponNode:first_attribute("name"):value()] = {
            scrap = node_get_number_default(resourceNode:first_node("scrap"), 0),
            fuel = node_get_number_default(resourceNode:first_node("fuel"), 0),
            missiles = node_get_number_default(resourceNode:first_node("missiles"), 0),
            drones = node_get_number_default(resourceNode:first_node("drones"), 0)
        }
    end
end)

--[[
////////////////////
LOGIC
////////////////////
]]--

-- Consume resources
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    local resourceCost = resourceWeapons[weapon and weapon.blueprint and weapon.blueprint.name]
    if weapon.iShipId == 0 and resourceCost and is_first_shot(weapon, true) then
        if resourceCost.scrap and resourceCost.scrap > 0 then
            Hyperspace.ships.player:ModifyScrapCount(-resourceCost.scrap, false)
        end
        if resourceCost.fuel and resourceCost.fuel > 0 then
            Hyperspace.ships.player.fuel_count = Hyperspace.ships.player.fuel_count - resourceCost.fuel
        end
        if resourceCost.missiles and resourceCost.missiles > 0 then
            Hyperspace.ships.player:ModifyMissileCount(-resourceCost.missiles)
        end
        if resourceCost.drones and resourceCost.drones > 0 then
            Hyperspace.ships.player:ModifyDroneCount(-resourceCost.drones)
        end
    end
end)

-- Reset weapon charge if required resources aren't available
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    local weapons = ship.iShipId == 0 and ship.weaponSystem and ship.weaponSystem.weapons
    if weapons then
        for weapon in vter(weapons) do
            local resourceCost = resourceWeapons[weapon.blueprint.name]
            if weapon.powered and resourceCost then
                if resourceCost.scrap and resourceCost.scrap > Hyperspace.ships.player.currentScrap then
                    reset_weapon_charge(weapon)
                elseif resourceCost.fuel and resourceCost.fuel > Hyperspace.ships.player.fuel_count then
                    reset_weapon_charge(weapon)
                elseif resourceCost.missiles and resourceCost.missiles > Hyperspace.ships.player:GetMissileCount() then
                    reset_weapon_charge(weapon)
                elseif resourceCost.drones and resourceCost.drones > Hyperspace.ships.player:GetDroneCount() then
                    reset_weapon_charge(weapon)
                end
            end
        end
    end
end, mods.multiverse.INT_MIN) -- Run last to be sure that anything else which affects weapon charge doesn't interfere

-- Add info to stats
script.on_internal_event(Defines.InternalEvents.WEAPON_STATBOX, function(bp, stats)
    local resourceCost = resourceWeapons[bp.name]
    if resourceCost then
        stats = stats.."\n"
        for resource, amount in pairs(resourceCost) do
            if amount > 0 then
                stats = stats.."\n"..string_replace(Hyperspace.Text:GetText("stat_resources_"..resource), "\\1", amount)
            end
        end
        return Defines.Chain.CONTINUE, stats
    end
end)
