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
                if weapon.powered and weapon.subCooldown.second <= weapon.subCooldown.first and not weapon.table["mods.multiverse.manualDecharge"] then
                    local oldFirst = weapon.cooldown.first
                    local oldSecond = weapon.cooldown.second

                    weapon.cooldown.first = weapon.cooldown.first + sensors:GetEffectivePower()*0.25*time_increment()
                    weapon.cooldown.first = math.min(weapon.cooldown.first, weapon.cooldown.second)
                    
                    if weapon.cooldown.second == weapon.cooldown.first and oldFirst < oldSecond and weapon.chargeLevel < weapon.blueprint.chargeLevels then
                        weapon.chargeLevel = weapon.chargeLevel + 1
                        weapon.weaponVisual.boostLevel = 0
                        weapon.weaponVisual.boostAnim:SetCurrentFrame(0)
                        if weapon.chargeLevel < weapon.blueprint.chargeLevels then weapon.cooldown.first = 0 end
                    else
                        weapon.subCooldown.first = weapon.subCooldown.first + time_increment()
                        weapon.subCooldown.first = math.min(weapon.subCooldown.first, weapon.subCooldown.second)
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
