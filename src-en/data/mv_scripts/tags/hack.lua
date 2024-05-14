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

local hackWeapons = {}
table.insert(weaponTagParsers, function(weaponNode)
    local hackNode = weaponNode:first_node("mv-hack")
    if hackNode then
        local hack = {}

        hack.duration = node_get_number_default(hackNode:first_attribute("duration"), 0)
        hack.immuneAfterHack = node_get_number_default(hackNode:first_attribute("immuneAfterHack"), 0)
        hack.hitShieldDuration = node_get_number_default(hackNode:first_attribute("hitShieldDuration"), 0)
        
        hack.systemDurations = {}
        for systemDuration in node_child_iter(hackNode) do
            local sysDurations = {}
            hack.systemDurations[systemDuration:name()] = sysDurations
            sysDurations.duration = systemDuration:value() and tonumber(systemDuration:value()) or hack.duration
            local hackImmuneNode = systemDuration:first_attribute("immuneAfterHack")
            if hackImmuneNode then
                sysDurations.immuneAfterHack = node_get_number_default(hackImmuneNode, 0)
            end
        end

        hackWeapons[weaponNode:first_attribute("name"):value()] = hack
    end
end)

--[[
////////////////////
LOGIC
////////////////////
]]--

-- Track hack time for systems hacked by a weapon
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    for system in vter(ship.vSystemList) do
        local sysHackData = userdata_table(system, "mods.mv.hackStuff")
        if sysHackData.time and sysHackData.time > 0 then
            if ship.bDestroyed then
                sysHackData.time = 0
            else
                sysHackData.time = math.max(sysHackData.time - time_increment(), 0)
            end
            if sysHackData.time == 0 then
                system.iHackEffect = 0
                system.bUnderAttack = false
            end
        elseif sysHackData.immuneTime and sysHackData.immuneTime > 0 then
            sysHackData.immuneTime = math.max(sysHackData.immuneTime - time_increment(), 0)
        end
    end
end)

-- General function for applying hack to a system on hit
local function apply_hack(hack, system)
    if system then
        local sysHackData = userdata_table(system, "mods.mv.hackStuff")
        if not sysHackData.immuneTime or sysHackData.immuneTime <= 0 then
            local sysDuration = hack.systemDurations and hack.systemDurations[Hyperspace.ShipSystem.SystemIdToName(system:GetId())]
            
            -- Set hacking time for system
            if sysDuration then
                sysHackData.time = math.max(sysDuration.duration, sysHackData.time or 0)
                sysHackData.immuneTime = math.max(sysDuration.immuneAfterHack or hack.immuneAfterHack or 0, sysHackData.immuneTime or 0)
            else
                sysHackData.time = math.max(hack.duration, sysHackData.time or 0)
                sysHackData.immuneTime = math.max(hack.immuneAfterHack or 0, sysHackData.immuneTime or 0)
            end
            
            -- Apply the actual hack effect
            system.iHackEffect = 2
            system.bUnderAttack = true
        end
    end
end

-- Handle hacking beams
script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    local hack = hackWeapons[projectile and projectile.extend and projectile.extend.name]
    if hack and hack.duration and hack.duration > 0 and beamHitType == Defines.BeamHit.NEW_ROOM then
        apply_hack(hack, shipManager:GetSystemInRoom(get_room_at_location(shipManager, location, true)))
    end
    return Defines.Chain.CONTINUE, beamHitType
end)

-- Handle other hacking weapons
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    local hack = hackWeapons[projectile and projectile.extend and projectile.extend.name]
    if hack and hack.duration and hack.duration > 0 then
        apply_hack(hack, shipManager:GetSystemInRoom(get_room_at_location(shipManager, location, true)))
    end
end)

-- Hack shields if shield bubble hit
script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
    local hack = hackWeapons[projectile and projectile.extend and projectile.extend.name]
    if hack and hack.hitShieldDuration and hack.hitShieldDuration > 0 then
        apply_hack({
            duration = hack.hitShieldDuration,
            immuneAfterHack = hack.systemDurations.shields and hack.systemDurations.shields.immuneAfterHack or hack.immuneAfterHack
        }, shipManager:GetSystem(0))
    end
end)

-- Add info to stats
script.on_internal_event(Defines.InternalEvents.WEAPON_STATBOX, function(bp, stats)
    local hack = hackWeapons[bp.name]
    if hack then
        stats = stats.."\n\n"..string_replace(Hyperspace.Text:GetText("stat_hack_time"), "\\1", hack.duration)
        if hack.immuneAfterHack and hack.immuneAfterHack > 0 then
            stats = stats.."\n"..string_replace(Hyperspace.Text:GetText("stat_hack_time_immune"), "\\1", hack.immuneAfterHack)
        end
        return Defines.Chain.CONTINUE, stats
    end
end)
