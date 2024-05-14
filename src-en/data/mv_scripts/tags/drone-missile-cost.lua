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

local missileDrones = {}
local deployedMissileDrones = {}
table.insert(droneTagParsers, function(droneNode)
    local missileCostNode = droneNode:first_node("mv-droneMissileCost")
    if missileCostNode then
        local cost = node_get_number_default(missileCostNode, 0)
        if cost > 0 then
            missileDrones[droneNode:first_attribute("name"):value()] = cost
        end
    end
end)

--[[
////////////////////
LOGIC
////////////////////
]]--

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    for drone in vter(ship.spaceDrones) do
        if drone.blueprint then
            local missileDeployCost = missileDrones[drone.blueprint.name]
            if missileDeployCost then
                if drone.deployed then
                    if not deployedMissileDrones[drone.selfId] then
                        deployedMissileDrones[drone.selfId] = true
                        if ship:GetMissileCount() >= missileDeployCost then
                            ship:ModifyMissileCount(-missileDeployCost)
                        else
                            drone:SetDestroyed(true, false)
                            ship:ModifyDroneCount(1)
                        end
                    end
                else
                    deployedMissileDrones[drone.selfId] = nil
                end
            end
        end
    end
end)
