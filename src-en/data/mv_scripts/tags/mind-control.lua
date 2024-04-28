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

local mcWeapons = {}
table.insert(weaponTagParsers, function(weaponNode)
    local mcNode = weaponNode:first_node("mv-mindControl")
    if mcNode then
        local mindControl = {}
        mindControl.duration = node_get_number_default(mcNode:first_node("duration"), 0)
        local mcLimit = node_get_number_default(mcNode:first_node("limit"), 0)
        if mcLimit > 0 then mindControl.limit = mcLimit end
        local mcSound = mcNode:first_node("sound")
        if mcSound and mcSound:value() then mindControl.sound = mcSound:value() end
        mcWeapons[weaponNode:first_attribute("name"):value()] = mindControl
    end
end)

--[[
////////////////////
LOGIC
////////////////////
]]--

-- Handle crew mind controlled by weapons
script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
    local mcTable = userdata_table(crewmem, "mods.mv.crewStuff")
    if mcTable.mcTime then
        if crewmem.bDead then
            mcTable.mcTime = nil
            mcTable.sound = nil
        else
            mcTable.mcTime = math.max(mcTable.mcTime - time_increment(), 0)
            if mcTable.mcTime == 0 then
                crewmem:SetMindControl(false)
                Hyperspace.Sounds:PlaySoundMix(mcTable.sound or "mindControlEnd", -1, false)
                mcTable.mcTime = nil
                mcTable.sound = nil
            end
        end
    end
end)

-- Handle mind control beams
script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    local mindControl = mcWeapons[projectile and projectile.extend and projectile.extend.name]
    if mindControl and mindControl.duration > 0 then -- Doesn't check realNewTile anymore 'cause the beam kept missing crew that were on the move
        for i, crewmem in ipairs(get_ship_crew_point(shipManager, location.x, location.y)) do
            if can_be_mind_controlled(crewmem) then
                crewmem:SetMindControl(true)
                local mcTable = userdata_table(crewmem, "mods.mv.crewStuff")
                mcTable.mcTime = math.max(mindControl.duration, mcTable.mcTime or 0)
                mcTable.sound = mindControl.sound
            elseif resists_mind_control(crewmem) and realNewTile then
                crewmem.bResisted = true
            end
        end
    end
    return Defines.Chain.CONTINUE, beamHitType
end)

-- Handle other mind control weapons
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    local mindControl = mcWeapons[projectile and projectile.extend and projectile.extend.name]
    if mindControl and mindControl.duration > 0 then
        local roomId = get_room_at_location(shipManager, location, true)
        local mindControlledCrew = 0
        for crewmem in vter(shipManager.vCrewList) do
            local doControl = crewmem.iRoomId == roomId and
                              crewmem.currentShipId == shipManager.iShipId and
                              crewmem.iShipId ~= projectile.ownerId
            if doControl then
                if can_be_mind_controlled(crewmem) then
                    crewmem:SetMindControl(true)
                    local mcTable = userdata_table(crewmem, "mods.mv.crewStuff")
                    mcTable.mcTime = math.max(mindControl.duration, mcTable.mcTime or 0)
                    mcTable.sound = mindControl.sound
                    mindControlledCrew = mindControlledCrew + 1
                    if mindControl.limit and mindControlledCrew >= mindControl.limit then break end
                elseif resists_mind_control(crewmem) then
                    crewmem.bResisted = true
                end
            end
        end
    end
end)

-- Add info to stats
script.on_internal_event(Defines.InternalEvents.WEAPON_STATBOX, function(bp, stats)
    local mindControl = mcWeapons[bp.name]
    if mindControl then
        stats = stats.."\n\n"..string_replace(Hyperspace.Text:GetText("stat_mc_time"), "\\1", mindControl.duration)
        if mindControl.limit then
            stats = stats.."\n"..string_replace(Hyperspace.Text:GetText("stat_mc_crew"), "\\1", mindControl.limit)
        end
        return Defines.Chain.CONTINUE, stats
    end
end)
