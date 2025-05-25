-- Double charge time for artillery if manual targeting upgrade is installed
script.on_internal_event(Defines.InternalEvents.WEAPON_COOLDOWN_MOD, function(weapon, mod, arty)
    local ship = Hyperspace.ships(weapon.iShipId)
    if arty and ship and (ship:HasAugmentation("UPG_ARTILLERY_TARGETING") > 0 or ship:HasAugmentation("EX_ARTILLERY_TARGETING") > 0) then
        return Defines.Chain.CONTINUE, mod*1.5
    end
end)
