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

local limitWeapons = {}
table.insert(weaponTagParsers, function(weaponNode)
    local limitNode = weaponNode:first_node("mv-sys-limit")
    if limitNode then
        local limit = {}
        limit.amount = node_get_number_default(limitNode:first_node("amount"), 0)
        limit.time = node_get_number_default(limitNode:first_node("time"), 0)
        limitWeapons[weaponNode:first_attribute("name"):value()] = limit
    end
end)

--[[
////////////////////
LOGIC
////////////////////
]]--

-- Save the limit to userdata table
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    local limit = limitWeapons[projectile and projectile.extend and projectile.extend.name]
    if limit and limit.amount > 0 and limit.time > 0 then
        local system = shipManager:GetSystemInRoom(get_room_at_location(shipManager, location, true))
        if system then
            local sysLimitData = userdata_table(system, "mods.mv.sysLimit")
            if not sysLimitData.amount or limit.amount >= sysLimitData.amount then
                sysLimitData.amount = math.max(sysLimitData.amount or 0, limit.amount)
                sysLimitData.time = math.max(sysLimitData.time or 0, limit.time)
            end
        end
    end
end)

-- Apply saved limits
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    for system in vter(shipManager.vSystemList) do
        local sysLimitData = userdata_table(system, "mods.mv.sysLimit")
        if sysLimitData.amount then
            system.extend.additionalPowerLoss = system.extend.additionalPowerLoss + sysLimitData.amount
            system:CheckMaxPower()
            system:CheckForRepower()
            sysLimitData.time = sysLimitData.time - time_increment()
            if sysLimitData.time <= 0 then
                sysLimitData.amount = nil
                sysLimitData.time = nil
            end
        end
    end
end)

-- Add info to stats
script.on_internal_event(Defines.InternalEvents.WEAPON_STATBOX, function(bp, stats)
    local limit = limitWeapons[bp.name]
    if limit and limit.amount > 0 and limit.time > 0 then
        stats = stats.."\n\n"..string_replace(Hyperspace.Text:GetText("stat_limit_amount"), "\\1", limit.amount)
        stats = stats.."\n"..string_replace(Hyperspace.Text:GetText("stat_limit_time"), "\\1", limit.time)
        return Defines.Chain.CONTINUE, stats
    end
end)
