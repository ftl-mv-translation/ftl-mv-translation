local userdata_table = mods.multiverse.userdata_table
local create_damage_message = mods.multiverse.create_damage_message
local damageMessages = mods.multiverse.damageMessages
local function bp_list_search(listName, element)
    if not (listName and element) then return nil end
    local list = Hyperspace.Blueprints:GetBlueprintList(listName)
    for i = 0, list:size() - 1 do
        if element == list[i] then
            return i
        end
    end
    return nil
end

-- Define damage reduction armor augments
mods.multiverse.reductionArmor = {
    --[[
    ARMOR_MISSILES = {
        amount = 1, -- The amount of damage the augment protects against
        weapons = "LIST_WEAPONS_MISSILES" -- Blueprint list of weapons the augment applies to (leave undefined to apply to all weapons)
    },
    --]]
    PALADIN_ARMOR = {
        amount = 1
    },
    LOCKED_PALADIN_ARMOR = {
        amount = 1
    },
    PALADIN_ARMOR_PLAYER = {
        amount = 2
    },
    CRYSTAL_ARMOR_100 = {
        amount = -1
    }
}
local reductionArmor = mods.multiverse.reductionArmor

-- Reduce damage for reduction armor
local function handle_reduction_armor(ship, projectile, location, damage, immediateDmgMsg)
    -- Check for damage reduction augments
    for augName, reductionData in pairs(reductionArmor) do
        if ship:HasAugmentation(augName) > 0 then
            -- Check if weapon is on the list of things to resist
            if not reductionData.weapons or bp_list_search(reductionData.weapons, projectile and projectile.extend and projectile.extend.name) then
                if reductionData.amount > 0 then
                    -- Check if incoming damage is greater than the reduction amount
                    if damage.iDamage > reductionData.amount then
                        -- Reduce damage
                        damage.iDamage = damage.iDamage - reductionData.amount
                    elseif damage.iDamage > 0 then
                        -- Otherwise roll a chance to negate the damage entirely based on the augment value
                        if math.random() < ship:GetAugmentationValue(augName) then
                            damage.iDamage = 0
                            if immediateDmgMsg == true then
                                create_damage_message(ship.iShipId, damageMessages.NEGATED, location.x, location.y)
                            else
                                userdata_table(projectile, "mods.mv.reductionArmor").showMsg = true
                            end
                        end
                    end
                elseif damage.iDamage > 0 then
                    -- Increase damage for negative values
                    damage.iDamage = damage.iDamage - reductionData.amount
                end
            end
        end
    end
end
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, handle_reduction_armor)
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(ship, projectile, location)
    if projectile and userdata_table(projectile, "mods.mv.reductionArmor").showMsg then
        create_damage_message(ship.iShipId, damageMessages.NEGATED, location.x, location.y)
    end
end)
script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(ship, projectile, location, damage, realNewTile, beamHitType)
    if beamHitType == Defines.BeamHit.NEW_ROOM then
        handle_reduction_armor(ship, projectile, location, damage, true)
    end
end)
