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

local crewTargetWeapons = {}
table.insert(weaponTagParsers, function(weaponNode)
    local crewTargetNode = weaponNode:first_node("mv-crewTarget")
    if crewTargetNode then
        crewTargetWeapons[weaponNode:first_attribute("name"):value()] = crewTargetNode:value()
    end
end)

--[[
////////////////////
LOGIC
////////////////////
]]--

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    local playerShip = Hyperspace.ships.player
    local crewTargetType = crewTargetWeapons[weapon and weapon.blueprint and weapon.blueprint.name]
    if weapon.iShipId == 1 and playerShip and crewTargetType then
        local targetRoom = nil
        if crewTargetType == "MOST_CREW" then
            -- Find the room on the player ship with the most crew
            local mostCrew = 0
            for currentRoom = 0, Hyperspace.ShipGraph.GetShipInfo(playerShip.iShipId):RoomCount() - 1 do
                local numCrew = playerShip:CountCrewShipId(currentRoom, 0)
                if numCrew > mostCrew then
                    mostCrew = numCrew
                    targetRoom = currentRoom
                end
            end
        elseif crewTargetType == "RANDOM" then
            -- Find any room on the player ship with crew
            local validTargets = {}
            for currentRoom = 0, Hyperspace.ShipGraph.GetShipInfo(playerShip.iShipId):RoomCount() - 1 do
                if playerShip:CountCrewShipId(currentRoom, 0) > 0 then
                    table.insert(validTargets, currentRoom)
                end
            end
            if #validTargets > 0 then
                targetRoom = validTargets[math.random(#validTargets)]
            end
        end
        
        -- Retarget the projectile to the selected room
        if targetRoom then
            projectile.target = playerShip:GetRoomCenter(targetRoom)
            projectile:ComputeHeading()
        end
    end
end)
