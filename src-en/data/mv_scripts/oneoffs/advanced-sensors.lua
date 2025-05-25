local vter = mods.multiverse.vter
local time_increment = mods.multiverse.time_increment

-- Cloak charging
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    local sensors = ship:GetSystem(7)
    if sensors and ship.weaponSystem and ship.weaponSystem.weapons and ship.weaponSystem.iHackEffect < 2 then
        -- Check for cloak charge
        local enemyShip = Hyperspace.ships(1 - ship.iShipId)
        local cloakCharge = ship:HasAugmentation("ADV_SCANNERS_CLOAK") > 0 and
                            enemyShip and
                            enemyShip.cloakSystem and
                            enemyShip.cloakSystem.bTurnedOn

        -- Manually charge weapons
        if cloakCharge then
            for weapon in vter(ship.weaponSystem.weapons) do
                if weapon.powered and weapon.cooldown.first < weapon.cooldown.second and not weapon.table["mods.multiverse.manualDecharge"] then
                    local currentCharge = weapon.cooldown.first + sensors:GetEffectivePower()*0.25*time_increment()
                    if currentCharge >= weapon.cooldown.second then
                        if weapon.chargeLevel < weapon.weaponVisual.iChargeLevels then
                            weapon.chargeLevel = weapon.chargeLevel + 1
                            if weapon.chargeLevel == weapon.weaponVisual.iChargeLevels then
                                weapon.cooldown.first = weapon.cooldown.second
                            else
                                weapon.cooldown.first = 0
                            end
                        else
                            weapon:ForceCoolup()
                        end
                    else
                        weapon.cooldown.first = currentCharge
                    end
                end
            end
        end
    end
end)

-- Bonus accuracy
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    local ship = Hyperspace.ships(projectile.ownerId)
    if ship and ship:HasAugmentation("ADV_SCANNERS_CLOAK") > 0 and ship:GetSystem(7) then
        projectile.extend.customDamage.accuracyMod = projectile.extend.customDamage.accuracyMod + math.ceil(ship:GetSystem(7):GetEffectivePower()*2.5)
    end
end)
