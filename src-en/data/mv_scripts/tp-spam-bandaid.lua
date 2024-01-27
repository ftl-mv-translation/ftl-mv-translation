--[[
CV: Since I don't know how to fix this properly and mathchamp is inactive,
this fix is here to make the issues with duskbringers teleporting around
erratically less severe.
--]]

local userdata_table = mods.multiverse.userdata_table

-- Remove TP move when crew room changes
local noTp = Hyperspace.StatBoostDefinition()
noTp.stat = Hyperspace.CrewStat.TELEPORT_MOVE
noTp.value = false
noTp.boostType = Hyperspace.StatBoostDefinition.BoostType.SET
noTp.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
noTp.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
noTp.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
noTp.duration = 3
script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crew)
    local _, tpMove = crew.extend:CalculateStat(Hyperspace.CrewStat.TELEPORT_MOVE)
    if tpMove and crew.iShipId == 1 and crew.currentShipId == 1 then
        local crewData = userdata_table(crew, "mods.multiverse.crewTpFix")
        if crewData.lastTpRoom and crewData.lastTpRoom ~= crew.iRoomId then
            Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(noTp), crew)
        end
        crewData.lastTpRoom = crew.iRoomId
    end
end)
