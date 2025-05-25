local vter = mods.multiverse.vter

local noAutoManSystems = {0, 1, 3, 8}
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if ship:HasAugmentation("SHIP_AUTO_FED") > 0 then
        -- Find all systems being manned by crew
        local mannedSystems = {}
        for crew in vter(ship.vCrewList) do
            if crew.bActiveManning and crew:Functional() then
                mannedSystems[crew.iManningId] = true
            end
        end

        -- For each system besides piloting and sensors not being manned by crew,
        -- disable automatic manning
        for _, sysId in ipairs(noAutoManSystems) do
            local system = ship:GetSystem(sysId)
            if system and not mannedSystems[sysId] then
                system.bManned = false
                system.iActiveManned = 0
            end
        end
    end
end)
