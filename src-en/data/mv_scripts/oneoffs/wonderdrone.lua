local string_starts = mods.multiverse.string_starts

-- Random list to pull from for each shot
local wonderMissile = Hyperspace.Blueprints:GetWeaponBlueprint("MISSILES_1")
local wonderLaser = Hyperspace.Blueprints:GetWeaponBlueprint("DRONE_LASER_COMBAT")
local wonderIon = Hyperspace.Blueprints:GetWeaponBlueprint("DRONE_ION_AMP_1")
local wonderBeam = Hyperspace.Blueprints:GetWeaponBlueprint("DRONE_BEAM_COMBAT")
local wonderShots = {
    wonderMissile,
    wonderLaser,
    wonderLaser,
    wonderIon,
    wonderIon,
    wonderBeam,
    wonderBeam
}

-- Random shot logic
script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, function(projectile, drone)
    if drone.blueprint.name == "COMBAT_RANDOM" then
        local shot = wonderShots[math.random(#wonderShots)]
        if not string_starts(drone.blueprint.weaponBlueprint, shot.name) then
            local space = Hyperspace.Global.GetInstance():GetCApp().world.space
            if shot.typeName == "MISSILES" then
                space:CreateMissile(shot, projectile.position, projectile.currentSpace, projectile.ownerId, projectile.target, projectile.destinationSpace, projectile.heading)
            else
                space:CreateLaserBlast(shot, projectile.position, projectile.currentSpace, projectile.ownerId, projectile.target, projectile.destinationSpace, projectile.heading)
            end
            projectile:Kill()
        end
        local sounds = shot.effects.launchSounds
        Hyperspace.Sounds:PlaySoundMix(sounds[math.random(0, sounds:size() - 1)], -1, false)
    end
end)
