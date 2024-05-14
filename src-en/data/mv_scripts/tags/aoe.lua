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

--[[
////////////////////
DATA & PARSER
////////////////////
]]--

local aoeWeapons = {}
table.insert(weaponTagParsers, function(weaponNode)
    local aoeNode = weaponNode:first_node("mv-aoe")
    if aoeNode then
        local aoeDamage = parse_damage_from_children(aoeNode)
        local aoeString = string_replace(Hyperspace.Text:GetText("stat_aoe"), "\\1", damage_to_string(aoeDamage))
        aoeWeapons[weaponNode:first_attribute("name"):value()] = {
            damage = aoeDamage,
            stats = aoeString
        }
    end
end)

--[[
////////////////////
LOGIC
////////////////////
]]--

-- Do damage to adjacent rooms
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    local weaponName = projectile and projectile.extend and projectile.extend.name
    local aoeDamage = aoeWeapons[weaponName] and aoeWeapons[weaponName].damage
    if aoeDamage then
        projectile.extend.name = ""
        for roomId, roomPos in pairs(get_adjacent_rooms(shipManager.iShipId, get_room_at_location(shipManager, location, false), false)) do
            shipManager:DamageArea(roomPos, aoeDamage, true)
        end
        projectile.extend.name = weaponName
    end
end)

-- Add info to stats
script.on_internal_event(Defines.InternalEvents.WEAPON_STATBOX, function(bp, stats)
    local aoeDamageStats = aoeWeapons[bp.name] and aoeWeapons[bp.name].stats
    if aoeDamageStats then
        return Defines.Chain.CONTINUE, stats.."\n\n"..aoeDamageStats
    end
end)
