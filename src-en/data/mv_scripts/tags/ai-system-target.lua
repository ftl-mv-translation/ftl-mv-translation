--[[
////////////////////
IMPORTS AND UTIL
////////////////////
]]--

-- Make functions from the core script that we need to use in this script local
local vter = mods.multiverse.vter

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

local systemTargetWeapons = {}
table.insert(weaponTagParsers, function(weaponNode)
    local systemTargetNode = weaponNode:first_node("mv-aiSystemTarget")
    if systemTargetNode then
        local attrSystem = systemTargetNode:first_attribute("system")
        local attrShip = systemTargetNode:first_attribute("ship")
        systemTargetWeapons[weaponNode:first_attribute("name"):value()] = {
            system = attrSystem and attrSystem:value() or "any",
            ship = attrShip and attrShip:value() or "player"
        }
    end
end)

--[[
////////////////////
LOGIC
////////////////////
]]--

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    local systemTarget = systemTargetWeapons[weapon and weapon.blueprint and weapon.blueprint.name]
    if weapon.iShipId == 1 and systemTarget and weapon.blueprint.typeName ~= "BURST" then
        local ship = (systemTarget.ship == "enemy") and Hyperspace.ships.enemy or Hyperspace.ships.player
        if ship and ship.vSystemList:size() > 0 then
            -- Direct projectile to the specified ship
            projectile.destinationSpace = ship.iShipId
            projectile.targetId = ship.iShipId
            if systemTarget.system == "damaged" then
                -- Find damaged systems
                local validTargets = {}
                for system in vter(ship.vSystemList) do
                    if system.healthState.first < system.healthState.second then
                        table.insert(validTargets, system)
                    end
                end
                -- Pick a random damaged system to target
                if #validTargets > 0 then
                    local room = validTargets[math.random(#validTargets)].roomId
                    projectile.target = ship:GetRoomCenter(room)
                    projectile:ComputeHeading()
                    return
                end
            else
                -- Target a specific system
                local system = Hyperspace.ShipSystem.NameToSystemId(systemTarget.system)
                if system > -1 then
                    system = ship:GetSystem(system)
                    if system then
                        projectile.target = ship:GetRoomCenter(system.roomId)
                        projectile:ComputeHeading()
                        return
                    end
                end
            end
            -- Target a random system
            local room = ship.vSystemList[math.random(ship.vSystemList:size()) - 1].roomId
            projectile.target = ship:GetRoomCenter(room)
            projectile:ComputeHeading()
        end
    end
end)
