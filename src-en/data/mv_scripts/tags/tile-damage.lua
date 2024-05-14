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

local tileDamageWeapons = {}
local farPoint = Hyperspace.Pointf(-2147483648, -2147483648)
table.insert(weaponTagParsers, function(weaponNode)
    local tileDamageNode = weaponNode:first_node("mv-tileDamage")
    if tileDamageNode and weaponNode:first_node("type"):value() == "BEAM" then
        local tileDamageMethod = node_get_number_default(tileDamageNode:first_attribute("method"), 0)
        if tileDamageMethod == 2 then -- Don't need any other data if method is 2
            tileDamageWeapons[weaponNode:first_attribute("name"):value()] = {
                method = tileDamageMethod
            }
            return
        end
        local tileDamage = parse_damage_from_children(tileDamageNode)
        local tileDamageStr = string_replace(Hyperspace.Text:GetText("stat_tile_beam"), "\\1", damage_to_string(tileDamage))
        tileDamageWeapons[weaponNode:first_attribute("name"):value()] = {
            damage = tileDamage,
            method = tileDamageMethod,
            stats = tileDamageStr
        }
    end
end)

--[[
////////////////////
LOGIC
////////////////////
]]--

-- Deal damage to individual tiles
script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    if Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, false) > -1 then
        local weaponName = projectile and projectile.extend and projectile.extend.name
        local tileDamage = tileDamageWeapons[weaponName]
        if tileDamage and ((tileDamage.method == 0 and beamHitType ~= Defines.BeamHit.SAME_TILE) or ((tileDamage.method == 1 or tileDamage.method == 2) and beamHitType == Defines.BeamHit.NEW_TILE)) then
            projectile.extend.name = ""
            if tileDamage.method == 2 then
                shipManager:DamageBeam(location, farPoint, damage)
            else
                shipManager:DamageBeam(location, farPoint, tileDamage.damage)
            end
            projectile.extend.name = weaponName
        end
    end
    return Defines.Chain.CONTINUE, beamHitType
end)

-- Add info to stats
script.on_internal_event(Defines.InternalEvents.WEAPON_STATBOX, function(bp, stats)
    local tileDamage = tileDamageWeapons[bp.name]
    if tileDamage then
        if tileDamage.method == 0 then
            return Defines.Chain.CONTINUE, stats.."\n\n"..tileDamage.stats.."\n"..Hyperspace.Text:GetText("stat_tile_beam_method_0")
        elseif tileDamage.method == 1 then
            return Defines.Chain.CONTINUE, stats.."\n\n"..tileDamage.stats.."\n"..Hyperspace.Text:GetText("stat_tile_beam_method_1")
        elseif tileDamage.method == 2 then
            return Defines.Chain.CONTINUE, stats.."\n\n"..Hyperspace.Text:GetText("stat_tile_beam_method_2")
        end
    end
end)
