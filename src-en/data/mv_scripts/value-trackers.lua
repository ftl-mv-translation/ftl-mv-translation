--[[
////////////////////
IMPORTS
////////////////////
]]--
-- Make functions from the core script that we need to use in this script local

local sign = mods.multiverse.sign

--[[
////////////////////
PLAYER HULL MISSING
////////////////////
]]--

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local playerShip = Hyperspace.ships.player
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and playerShip then
        Hyperspace.playerVariables.loc_player_hull_missing = playerShip.ship.hullIntegrity.second - playerShip.ship.hullIntegrity.first
    end
end)

--[[
////////////////////
ENEMY SYSTEM LEVELS
////////////////////
]]--

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local enemyShip = Hyperspace.ships.enemy
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and enemyShip then
        if enemyShip.bDestroyed or enemyShip.bJumping then
            for id, sys in pairs(mods.multiverse.systemIds) do
                Hyperspace.playerVariables[sys.."_enemy"] = 0
            end
        else
            for id, sys in pairs(mods.multiverse.systemIds) do
                local level = enemyShip:HasSystem(id) and enemyShip:GetSystem(id).powerState.second or 0
                Hyperspace.playerVariables[sys.."_enemy"] = level
            end
        end
    end
end)
script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(ship)
    if ship.iShipId == 0 then
        for id, sys in pairs(mods.multiverse.systemIds) do
            Hyperspace.playerVariables[sys.."_enemy"] = 0
        end
    end
end)

--[[
////////////////////
PLAYER SYSTEM MAXIMUMS
////////////////////
]]--

local setSystemMaxVars = false
script.on_init(function() setSystemMaxVars = true end)
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if not (setSystemMaxVars and Hyperspace.ships.player) then return end
    local sysInfo = Hyperspace.ships.player.myBlueprint.systemInfo
    for id, sys in pairs(mods.multiverse.systemIds) do
        if sysInfo:has_key(id) then
            Hyperspace.playerVariables[sys.."_cap"] = sysInfo[id].maxPower
        else
            Hyperspace.playerVariables[sys.."_cap"] = 0
        end
    end
end)

--[[
////////////////////
FINAL BOSS FIGHT
////////////////////
]]--

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local enemyShip = Hyperspace.ships.enemy
    if enemyShip and not enemyShip.bDestroyed then
        local bossList = Hyperspace.Global.GetInstance():GetBlueprints():GetBlueprintList("LIST_SHIPS_FINALBOSS")
        for i = 0, bossList:size() - 1 do
            if enemyShip.myBlueprint.blueprintName == bossList[i] then
                Hyperspace.playerVariables.loc_finalboss = 1
                return
            end
        end
    end
    Hyperspace.playerVariables.loc_finalboss = 0
end)

--[[
////////////////////
COMBINED REPUTATIONS
////////////////////
]]--

mods.multiverse.repCombos = {}
local repCombos = mods.multiverse.repCombos
repCombos.rep_comb_federation = {
    rep_general = {buffer = 0},
    rep_union = {buffer = 1},
    rep_engi = {buffer = 1},
    rep_zoltan = {buffer = 1},
    rep_orchid = {buffer = 1},
    rep_crystal = {buffer = 1},
    rep_freemantis = {buffer = 2},
    rep_outcast = {buffer = 2}
}
repCombos.rep_comb_union = {
    rep_general = {buffer = 0},
    rep_union = {buffer = 0},
    rep_vampweed = {buffer = 1} -- At 2/3 Union notoriety, 1/2 Vamp notoriety is gained : buffer is a delay --
}
repCombos.rep_comb_engi = {
    rep_engi = {buffer = 0},
    rep_general = {buffer = 0},
    rep_zoltan = {buffer = 1}
}
repCombos.rep_comb_zoltan = {
    rep_zoltan = {buffer = 0},
    rep_general = {buffer = 0},
    rep_engi = {buffer = 1}
}
repCombos.rep_comb_freemantis = {
    rep_freemantis = {buffer = 0},
    rep_general = {buffer = 1},
    rep_zoltan = {buffer = 1, invert = true}
}
repCombos.rep_comb_outcast = {
    rep_outcast = {buffer = 0},
    rep_general = {buffer = 1}
}
repCombos.rep_comb_crystal = {
    rep_crystal = {buffer = 0},
    rep_general = {buffer = 1}
}
repCombos.rep_comb_orchid = {
    rep_orchid = {buffer = 0},
    rep_general = {buffer = 0}
}
repCombos.rep_comb_vampweed = {
    rep_vampweed = {buffer = 0},
    rep_general = {buffer = 1},
    rep_union = {buffer = 1},
    rep_shell = {buffer = 1}
}
repCombos.rep_comb_shell = {
    rep_shell = {buffer = 0},
    rep_general = {buffer = 1},
    rep_vampweed = {buffer = 1}
}
repCombos.rep_comb_slaver = {
    rep_slaver = {buffer = 0},
    rep_pirate = {buffer = 0}
}
repCombos.rep_comb_merc = {
    rep_mercenary = {buffer = 0},
    rep_pirate = {buffer = 0}
}
repCombos.rep_comb_smuggler = {
    rep_smuggler = {buffer = 0},
    rep_pirate = {buffer = 0}
}
repCombos.rep_comb_all = {
	rep_general = {buffer = 0},
	rep_union = {buffer = 0},
	rep_engi = {buffer = 0},
	rep_zoltan = {buffer = 0},
	rep_orchid = {buffer = 0},
	rep_crystal = {buffer = 0},
	rep_freemantis = {buffer = 0},
	rep_outcast = {buffer = 0},
	rep_vampweed = {buffer = 0},
	rep_shell = {buffer = 0}
}

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    for repComboName, componentReps in pairs(repCombos) do
        local totalRep = 0
        for repComponentName, repComponentData in pairs(componentReps) do
            local value = Hyperspace.playerVariables[repComponentName]
            if repComponentData.invert then value = -value end
            if math.abs(value) > repComponentData.buffer then
                totalRep = totalRep + value - repComponentData.buffer*sign(value)
            end
        end
        Hyperspace.playerVariables[repComboName] = totalRep
    end
end)
