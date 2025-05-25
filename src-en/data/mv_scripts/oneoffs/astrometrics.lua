mods.multiverse.astrometricsSectors = {
    multiverse = {
        civilian = 8,
        neutral = 6,
        hostile = 6,
        hazard = 9
    }
}

local sectorTypes = {
    civilian = "",
    neutral = "",
    hostile = "",
    hazard = ""
}

script.on_game_event("ATLAS_MENU", false, function()
    if Hyperspace.ships.player:HasAugmentation("ASTROMETRICS") then
        -- Pick a mod to pull from for each sector type
        for sectorType, _ in pairs(sectorTypes) do
            local modIds = {}
            local weightSum = 0

            for modId, sectorAmounts in pairs(mods.multiverse.astrometricsSectors) do
                -- Reset selectors
                Hyperspace.playerVariables["loc_astrometrics_"..sectorType.."_"..modId] = 0

                -- Collect all mods and set their weight by the number of sectors
                local weight = sectorAmounts[sectorType]
                if weight > 0 then
                    weightSum = weightSum + weight
                    table.insert(modIds, {
                        id = modId,
                        weight = weight
                    })
                end
            end

            -- Pick a random sector using the weights
            local rnd = math.random(weightSum);
            for i = 1, #modIds do
                if rnd <= modIds[i].weight then
                    sectorTypes[sectorType] = modIds[i].id
                    break
                end
                rnd = rnd - modIds[i].weight
            end
        end

        -- Pick a sector for each type
        for sectorType, modId in pairs(sectorTypes) do
            Hyperspace.playerVariables["loc_astrometrics_"..sectorType.."_"..modId] = 1
            Hyperspace.playerVariables["loc_astrometrics_"..sectorType] = math.random(mods.multiverse.astrometricsSectors[modId][sectorType]) - 1
        end
    end
end)
