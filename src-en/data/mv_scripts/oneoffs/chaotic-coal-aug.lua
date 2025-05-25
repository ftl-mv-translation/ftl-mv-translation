local reductionArmor = mods.multiverse.reductionArmor

local chaosWeapons = {
    "ENERGY_1",
    "ENERGY_2",
    "LASER_BURST_2",
    "LASER_LIGHT",
    "LASER_FROST_1",
    "LASER_FROST_2",
    "ENERGY_STUN",
    "LASER_PIERCE",
    "ION_HEAVY"
}

local function launch_random_projectile_damage(ship, location, damage)
    for i = 1, damage.iDamage do
        local bp = Hyperspace.Blueprints:GetWeaponBlueprint(chaosWeapons[math.random(#chaosWeapons)])
        Hyperspace.App.world.space:CreateLaserBlast(bp,
            location,
            ship.iShipId,
            ship.iShipId,
            Hyperspace.ships(1 - ship.iShipId):GetRandomRoomCenter(),
            1 - ship.iShipId,
            math.random(0, 360)
        )
    end
end

local function is_chaos_coal_augmentation(ship, damage)
    return ship and ship:HasAugmentation("ANTICOAL_AUG_CHAOS") > 0 and damage.iDamage > 0 and Hyperspace.ships(1 - ship.iShipId)
end

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(ship, projectile, location, damage, shipFriendlyFire)
    if is_chaos_coal_augmentation(ship, damage) then
        launch_random_projectile_damage(ship, location, damage)
    end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(ship, projectile, location, damage, newTile, beamHit)
    if beamHit == Defines.BeamHit.NEW_ROOM and is_chaos_coal_augmentation(ship, damage) then
        launch_random_projectile_damage(ship, location, damage)
    end
end)
