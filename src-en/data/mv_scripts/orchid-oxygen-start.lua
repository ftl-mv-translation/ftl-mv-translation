local vter = mods.multiverse.vter

local function fill_oxygenator_rooms(ship)
    for crew in vter(ship.vCrewList) do
        if crew.extend:CalculateStat(Hyperspace.CrewStat.OXYGEN_CHANGE_SPEED) > 0.13 and crew.iRoomId > -1 then
            ship.oxygenSystem.oxygenLevels[crew.iRoomId] = 100
        end
    end
end
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if not Hyperspace.App.world.bStartedGame then fill_oxygenator_rooms(ship) end
end)
script.on_init(function(newGame)
    if (newGame) then fill_oxygenator_rooms(Hyperspace.ships.player) end
end)
