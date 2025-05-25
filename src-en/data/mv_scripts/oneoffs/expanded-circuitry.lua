local vter = mods.multiverse.vter

-- Make crew in piloting give their bonus power to engines
script.on_internal_event(Defines.InternalEvents.SET_BONUS_POWER, function(system, amount)
    local ship = Hyperspace.ships(system._shipObj.iShipId)
    if ship and system:GetId() == 1 and (ship:HasAugmentation("EX_PILOT_REROUTE") > 0 or ship:HasAugmentation("UPG_PILOT_REROUTE") > 0) then
        local pilotRoom = ship:GetSystemRoom(6)
        for crew in vter(ship.vCrewList) do
            if crew.iRoomId == pilotRoom and crew.iShipId == ship.iShipId and crew:Functional() then
                local crewPower, _ = crew.extend:CalculateStat(Hyperspace.CrewStat.BONUS_POWER)
                amount = amount + crewPower
            end
        end
    end
    return Defines.Chain.CONTINUE, amount
end)
