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

-- Capitalize a word
local function string_word_title_case(str)
    return string.upper(string.sub(str, 1, 1))..string.lower(string.sub(str, 2, #str))
end

--[[
////////////////////
DATA & PARSER
////////////////////
]]--

local droneWeapons = {}
table.insert(weaponTagParsers, function(weaponNode)
    local droneShootNode = weaponNode:first_node("mv-droneShooter")
    if droneShootNode then
        droneWeapons[weaponNode:first_attribute("name"):value()] = {
            drone = Hyperspace.Blueprints:GetDroneBlueprint(droneShootNode:first_node("drone"):value()),
            shots = node_get_number_default(droneShootNode:first_node("shots"), 2)
        }
    end
end)

--[[
////////////////////
LOGIC
////////////////////
]]--

-- Convert projectile to drone when it reaches the enemy space
script.on_internal_event(Defines.InternalEvents.PROJECTILE_PRE, function(projectile)
    local droneWeaponData = droneWeapons[projectile and projectile.extend and projectile.extend.name]
    if droneWeaponData and projectile.ownerId ~= projectile.currentSpace then
        local ship = Hyperspace.ships(projectile.ownerId)
        local otherShip = Hyperspace.ships(1 - projectile.ownerId)
        if ship and otherShip then
            local drone = spawn_temp_drone(
                droneWeaponData.drone,
                ship,
                otherShip,
                projectile.target,
                droneWeaponData.shots,
                projectile.position)
            userdata_table(drone, "mods.mv.droneStuff").clearOnJump = true
        end
        projectile:Kill()
    end
end)

-- Delete drones on jump
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if ship.bJumping then
        for drone in vter(ship.spaceDrones) do
            if userdata_table(drone, "mods.mv.droneStuff").clearOnJump then
                drone:SetDestroyed(true, false)
            end
        end
    end
end)

-- Add info to stats
script.on_internal_event(Defines.InternalEvents.WEAPON_STATBOX, function(bp, stats)
    local droneWeaponData = droneWeapons[bp.name]
    if droneWeaponData then
        local droneType = Hyperspace.Blueprints:GetWeaponBlueprint(droneWeaponData.drone.weaponBlueprint).typeName
        droneType = string_replace(Hyperspace.Text:GetText("stat_drone_type"), "\\1", string_word_title_case(droneType))
        local droneShots = string_replace(Hyperspace.Text:GetText("stat_drone_shots"), "\\1", droneWeaponData.shots)
        local droneSpeed = string_replace(Hyperspace.Text:GetText("stat_drone_speed"), "\\1", math.floor(droneWeaponData.drone.speed))
        return Defines.Chain.CONTINUE, stats.."\n\n"..droneType.."\n"..droneShots.."\n"..droneSpeed
    end
end)
