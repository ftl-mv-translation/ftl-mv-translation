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
local check_paused = mods.multiverse.check_paused

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

local prideBeams = {}
table.insert(weaponTagParsers, function(weaponNode)
    if weaponNode:first_node("mv-prideBeam") then
        prideBeams[weaponNode:first_attribute("name"):value()] = true
    end
end)

--[[
////////////////////
LOGIC
////////////////////
]]--

-- Helper function to smoothly shift hue
local function hue2rgb(hue)
    hue = (hue % 1.0)*6
    local r, g, b = 0, 0, 0
    local X = 1 * (1 - math.abs(hue % 2 - 1))
    if     hue < 1 then r, g, b = 1, X, 0
    elseif hue < 2 then r, g, b = X, 1, 0
    elseif hue < 3 then r, g, b = 0, 1, X
    elseif hue < 4 then r, g, b = 0, X, 1
    elseif hue < 5 then r, g, b = X, 0, 1
    else                r, g, b = 1, 0, X
    end
    return r, g, b
end

-- Calculate the amount of time the beam should exist
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    if prideBeams[weapon.blueprint.name] then
        local speed = (weapon.blueprint.speed > 0) and weapon.blueprint.speed or 5
        local beamTime = weapon.blueprint.length/(speed*16)
        local projData = {}
        projectile.table["mods.mv.gayStuff"] = projData
        projData.lifetime = beamTime
        projData.lifetimeCurrent = beamTime

        -- Set initial color
        projectile.color.r = 255
        projectile.color.g = 0
        projectile.color.b = 0
    end
end)

-- Change color for pride pride beams
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if not check_paused() then
        for projectile in vter(Hyperspace.App.world.space.projectiles) do
            local projData = projectile.table["mods.mv.gayStuff"]
            if projData then
                -- Tick timer
                projData.lifetimeCurrent = projData.lifetimeCurrent - time_increment()

                -- Calculate color
                local r, g, b = hue2rgb(1 - projData.lifetimeCurrent/projData.lifetime)
                projectile.color.r = r*255
                projectile.color.g = g*255
                projectile.color.b = b*255
            end
        end
    end
end)
