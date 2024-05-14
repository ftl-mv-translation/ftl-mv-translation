-- Allow the pro-hull beam to be visible while also repairing hull.

mods.multiverse.beamDamageMods = {}
local beamDamageMods = mods.multiverse.beamDamageMods
beamDamageMods["BEAM_REPAIR"] = {iDamage = -2}

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    local damageMods = beamDamageMods[projectile.extend.name]
    if damageMods then
        for damageType, value in pairs(damageMods) do
            damage[damageType] = value
        end
    end
    return Defines.Chain.CONTINUE, beamHitType
end)
