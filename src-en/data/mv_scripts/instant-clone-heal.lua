local systemIds = mods.multiverse.systemIds
local sign = mods.multiverse.sign
local vter = mods.multiverse.vter

-- Put the crew ID or power definition in these tables if they're mistaken to be crew or self healers
local crewHealBlackList = {}
local selfHealBlackList = {}
mods.multiverse.crewHealBlackList = crewHealBlackList
mods.multiverse.selfHealBlackList = selfHealBlackList

local MEDBAY_HEAL = 6.4
local SUFFOCATION_DOT = 6.4

local alliedCrewTargets = {
    [Hyperspace.StatBoostDefinition.CrewTarget.ALLIES] = true,
    [Hyperspace.StatBoostDefinition.CrewTarget.ALL] = true,
    [Hyperspace.StatBoostDefinition.CrewTarget.CURRENT_ALLIES] = true,
    [Hyperspace.StatBoostDefinition.CrewTarget.ORIGINAL_ALLIES] = true
}

local validShipTargets = {
    [Hyperspace.StatBoostDefinition.ShipTarget.PLAYER_SHIP] = true,
    [Hyperspace.StatBoostDefinition.ShipTarget.CURRENT_ALL] = true,
    [Hyperspace.StatBoostDefinition.ShipTarget.CURRENT_ROOM] = true,
    [Hyperspace.StatBoostDefinition.ShipTarget.ORIGINAL_SHIP] = true,
    [Hyperspace.StatBoostDefinition.ShipTarget.CREW_TARGET] = true
}

local standardHealStats = {
    [Hyperspace.CrewStat.PASSIVE_HEAL_AMOUNT] = true,
    [Hyperspace.CrewStat.ACTIVE_HEAL_AMOUNT] = true
}

local trueHealStats = {
    [Hyperspace.CrewStat.TRUE_PASSIVE_HEAL_AMOUNT] = true,
    [Hyperspace.CrewStat.TRUE_HEAL_AMOUNT] = true
}

local otherHealStats = {
    [Hyperspace.CrewStat.HEAL_CREW_AMOUNT] = true,
    --[Hyperspace.CrewStat.HEAL_SPEED_MULTIPLIER] = true
}

local TableWithCount = setmetatable({
    __new = function(self)
        local tbl = {count = 0}
        return setmetatable(tbl, self)
    end,

    add = function(self, value)
        self.count = self.count + 1
        self[self.count] = value
    end,

    remove = function(self, index)
        table.remove(self, index)
        self.count = self.count - 1
    end,

    __len = function(self) return self.count end
}, {__call = function(tbl) return tbl:__new() end})
TableWithCount.__index = TableWithCount

local function get_toggle_number(toggleValue)
    return toggleValue.enabled and toggleValue.value or 0
end

local function vector_contains(vector, value)
    for item in vter(vector) do
        if item == value then
            return true
        end
    end

    return false
end

local function is_ship_stable(ship) -- Check if the ship doesn't have a fire and doesn't have a destroyed oxygen system
    return (ship.fireSpreader.count == 0 and not (ship:HasSystem(2) and ship.oxygenSystem:CompletelyDestroyed()))
end

local function is_ship_super_stable(ship) -- As above, but also check if no systems are breached
    if not is_ship_stable(ship) then return false end

    local systemsUnbreached = true
    for system in vter(ship.vSystemList) do
        if system.bBreached then
            systemsUnbreached = false
            break
        end
    end

    return systemsUnbreached
end

-- -1, the crew member is receiving a net DoT effect. Do not automatically heal.
-- 0, the crew member's health is not changing. Automatically heal if a healer is available.
-- 1, the crew member is actively healing. Automatically heal.
local function crew_healing_status(crew)
    local healthEffect = 0
    local passiveHealthEffect = 0
    local healSpeed = crew.extend:CalculateStat(Hyperspace.CrewStat.HEAL_SPEED_MULTIPLIER)

    passiveHealthEffect = passiveHealthEffect + (crew.extend:CalculateStat(Hyperspace.CrewStat.PASSIVE_HEAL_AMOUNT) * healSpeed)
    passiveHealthEffect = passiveHealthEffect + crew.extend:CalculateStat(Hyperspace.CrewStat.TRUE_PASSIVE_HEAL_AMOUNT)
    healthEffect = healthEffect + (crew.extend:CalculateStat(Hyperspace.CrewStat.ACTIVE_HEAL_AMOUNT) * healSpeed)
    healthEffect = healthEffect + crew.extend:CalculateStat(Hyperspace.CrewStat.TRUE_HEAL_AMOUNT)

    local medbayEffect = MEDBAY_HEAL * (crew.fMedbay > 1 and 1.5 * (crew.fMedbay - 1) or crew.fMedbay)
    healthEffect = healthEffect + (medbayEffect * healSpeed)

    for otherCrew in vter(Hyperspace.ships.player.vCrewList) do
        if otherCrew.iRoomId == crew.iRoomId and otherCrew ~= crew then
            healthEffect = healthEffect + (otherCrew.extend:CalculateStat(Hyperspace.CrewStat.HEAL_CREW_AMOUNT) * healSpeed)
        end
    end

    if crew.bSuffocating then
        healthEffect = healthEffect - (SUFFOCATION_DOT * crew.extend:CalculateStat(Hyperspace.CrewStat.SUFFOCATION_MODIFIER))
    end

    -- passive health effects don't work if being damaged, and crew shouldn't be instantly
    -- healed if they're being affected by medbay but it isn't enough
    if healthEffect < 0 or ((healthEffect + passiveHealthEffect) == 0 and crew.fMedbay > 0) then
        return -1
    else
        return sign(healthEffect + passiveHealthEffect)
    end
end

local function crew_heals_self(crew)
    local crewDef = crew.extend:GetDefinition()
    local healAmount = crewDef.healSpeed * (crewDef.passiveHealAmount + crewDef.healAmount)
                     + (crewDef.truePassiveHealAmount + crewDef.trueHealAmount)

    return healAmount > 0 and crew_healing_status(crew) > 0
end

local function crew_is_healer_without_power(crew)
    local healCrewAmount, _ = crew.extend:CalculateStat(Hyperspace.CrewStat.HEAL_CREW_AMOUNT)
    return healCrewAmount > 0 and not crewHealBlackList[crew.species]
end

local function systems_on_ship(ship)
    local systems = {byId = {}, byName = {}}

    for system in vter(ship.vSystemList) do
        systems.byId[system:GetId()] = system
        systems.byName[system.name] = system
    end

    return systems
end

local function can_use_power(crew, power)
    if not power.enabled then
        return false
    end

    if select(2, crew.extend:CalculateStat(Hyperspace.CrewStat.SILENCED)) then
        return false
    end

    local req = power.def.playerReq

    if req.enemyShip or req.enemyInRoom or req.aiDisabled or req.inCombat then
        return false
    end

    if not (req.extraConditions:empty() and req.extraOrConditions:empty()) then
        return false
    end

    local playerShip = Hyperspace.ships.player
    local presentSystems = systems_on_ship(playerShip).byId
    local hasDamagedSystem = false

    for _, system in pairs(presentSystems) do
        if system.healthState.first < system.healthState.second then
            hasDamagedSystem = true
            break
        end
    end

    if (req.systemDamaged and not hasDamagedSystem) or (req.hasClonebay and not presentSystems[13])
    or (req.requiredSystem >= 0 and (not presentSystems[req.requiredSystem] or (req.requiredSystemFunctional and presentSystems[req.requiredSystem].healthState <= 0)))
    then
        return false
    end

    if crew.health.first < get_toggle_number(req.minHealth) or (req.maxHealth.enabled and crew.health.first > req.maxHealth.value) then
        return false
    end

    return true
end

local function stat_boost_affects_health(statBoost)
    if not validShipTargets[statBoost.shipTarget] then return false end
    if not (alliedCrewTargets[statBoost.crewTarget] or statBoost.affectsSelf) then return false end

    return standardHealStats[statBoost.stat] or trueHealStats[statBoost.stat] or otherHealStats[statBoost.stat]
end

local function health_affecting_stat_boosts(...)
    local validStatBoosts = TableWithCount()

    for _, statBoosts in ipairs({...}) do
        for statBoost in vter(statBoosts) do
            if statBoost.stat == Hyperspace.CrewStat.STAT_BOOST then
                local validSubStatBoosts = health_affecting_stat_boosts(statBoost.providedStatBoosts)
                local subCount = validSubStatBoosts.count

                table.move(validSubStatBoosts, 1, subCount, validStatBoosts.count + 1, validStatBoosts)
                validStatBoosts.count = validStatBoosts.count + subCount
            elseif stat_boost_affects_health(statBoost) then
                validStatBoosts:add(statBoost)
            end
        end
    end

    return validStatBoosts
end

-- -1 if power kills the crew member or ends up harming them
-- 0 if there is no net effect on the crew member's health
-- 1 if using the power causes a net heal
local function power_net_self_health_effect(power, crew)
    local powerDef = power.def
    local tempPower = powerDef.tempPower

    if (crew.health.second + powerDef.selfHealth <= 0) or (tempPower.maxHealth.enabled and tempPower.maxHealth <= 0) then
        return -1
    end

    local healSpeed = crew.extend:CalculateStat(Hyperspace.CrewStat.HEAL_SPEED_MULTIPLIER)
    local healthEffect = powerDef.selfHealth

    healthEffect = healthEffect + (get_toggle_number(tempPower.passiveHealAmount) * healSpeed * tempPower.duration)
    healthEffect = healthEffect + (get_toggle_number(tempPower.truePassiveHealAmount) * tempPower.duration)
    healthEffect = healthEffect + (get_toggle_number(tempPower.healAmount) * healSpeed * tempPower.duration)
    healthEffect = healthEffect + (get_toggle_number(tempPower.trueHealAmount) * tempPower.duration)

    local relevantStatBoosts = health_affecting_stat_boosts(powerDef.statBoosts, powerDef.roomStatBoosts)
    local relevantTempStatBoosts = health_affecting_stat_boosts(tempPower.statBoosts)
    local sizeDifference = relevantStatBoosts.count - relevantTempStatBoosts.count

    for i, statBoost in ipairs(relevantStatBoosts) do
        if i > sizeDifference then
            break
        end

        if statBoost.affectsSelf and statBoost.stat ~= Hyperspace.CrewStat.HEAL_CREW_AMOUNT then
            local duration = (statBoost.duration >= 0 and statBoost.duration or 100000)
            local amount = statBoost.amount * duration * (standardHealStats[statBoost.stat] and healSpeed or 1)

            healthEffect = healthEffect + amount
        end
    end
    for _, statBoost in ipairs(relevantTempStatBoosts) do
        if statBoost.affectsSelf and statBoost.stat ~= Hyperspace.CrewStat.HEAL_CREW_AMOUNT then
            local duration = math.min(tempPower.duration, (statBoost.duration >= 0 and statBoost.duration or 100000))
            local amount = statBoost.amount * duration * (standardHealStats[statBoost.stat] and healSpeed or 1)

            healthEffect = healthEffect + amount
        end
    end

    if selfHealBlackList[crew.species] or selfHealBlackList[power.def] then
        healthEffect = math.min(healthEffect, 0)
    end

    return sign(healthEffect)
end

local function stat_boosts_heal(statBoosts)
    for _, statBoost in ipairs(statBoosts) do
        if statBoost.amount > 0 and (alliedCrewTargets[statBoost.crewTarget] or statBoost.stat == Hyperspace.CrewStat.HEAL_CREW_AMOUNT) then
            return true
        end
    end

    return false
end

local function power_is_healer(power, crew)
    if crewHealBlackList[power.def] then
        return false
    end

    if not (can_use_power(crew, power) and power.powerCharges.second < 0) then
        return false
    end

    local netSelfHealthEffect = power_net_self_health_effect(power, crew)
    if netSelfHealthEffect ~= 0 then
        return netSelfHealthEffect > 0
    end

    local powerDef = power.def
    local tempPower = powerDef.tempPower

    if powerDef.crewHealth > 0 or get_toggle_number(tempPower.healCrewAmount) > 0 then
        return true
    end

    local relevantStatBoosts = health_affecting_stat_boosts(powerDef.statBoosts, powerDef.roomStatBoosts, tempPower.statBoosts)
    return stat_boosts_heal(relevantStatBoosts)
end

local function aug_is_healer(augDef)
    return stat_boosts_heal(health_affecting_stat_boosts(augDef.statBoosts))
end

local function get_healers_on_ship(ship)
    local healers = TableWithCount()

    if ship:HasSystem(5) then -- medbay
        healers:add(ship:GetSystem(5))
    end

    if ship:HasSystem(4) then -- dronebay
        healers:add(ship:GetSystem(4))
    end

    for crew in vter(ship.vCrewList) do
        if crew_healing_status(crew) >= 0 and (crew:IsCrew() or crew:Functional()) and not crewHealBlackList[crew.species] then
            if crew_is_healer_without_power(crew) then
                healers:add(crew)
            else
                for power in vter(crew.extend.crewPowers) do
                    if power_is_healer(power, crew) then
                        healers:add(power)
                    end
                end
            end
        end
    end

    local augManager = Hyperspace.CustomAugmentManager.GetInstance()
    for aug in vter(augManager:GetShipAugments(ship.iShipId):keys()) do
        if not crewHealBlackList[aug] and augManager:IsAugment(aug) then
            local augDef = augManager:GetAugmentDefinition(aug)
            if aug_is_healer(augDef) then
                healers:add(augDef)
            end
        end
    end

    return healers
end

local function stat_boost_affects_crew(statBoost, crew)
    if statBoost.stat == Hyperspace.CrewStat.HEAL_CREW_AMOUNT then
        return true
    end

    if not alliedCrewTargets[statBoost.crewTarget] then
        return false
    end

    if statBoost.droneTarget == Hyperspace.StatBoostDefinition.DroneTarget.DRONES and crew:IsCrew()
    or statBoost.droneTarget == Hyperspace.StatBoostDefinition.DroneTarget.CREW and crew:IsDrone()
    then
        return false
    end

    if not statBoost.whiteList:empty() and not vector_contains(statBoost.whiteList, crew.species) then
        return false
    end

    if not statBoost.blackList:empty() and vector_contains(statBoost.blackList, crew.species) then
        return false
    end

    return true
end

local function stat_boost_multiplier_on_ship(statBoost, ship)
    local systems = systems_on_ship(ship)

    if not statBoost.systemList:empty() and statBoost.systemRoomTarget == Hyperspace.StatBoostDefinition.SystemRoomTarget.ALL then
        local hasValidSystem = false
        for systemName in vter(statBoost.systemList) do
            if systems.byName[systemName] or systemName == "all" then
                hasValidSystem = true
                break
            end
        end

        if not hasValidSystem then return 0 end
    end

    if not statBoost.systemPowerScaling:empty() then
        local reactor = Hyperspace.PowerManager.GetPowerManager(ship.iShipId)
        -- -1 because this is used as an index into a vector, so it needs to be 1 less
        local scaleLevel = -1

        for systemId in vter(statBoost.systemPowerScaling) do
            local system = systems.byId[systemId]
            if system then
                scaleLevel = math.max(scaleLevel, 0)
                scaleLevel = scaleLevel + system:GetEffectivePower()
            elseif systemId == 16 or systemId == 17 then
                scaleLevel = math.max(scaleLevel, 0)
                scaleLevel = scaleLevel + (systemId == 16 and reactor:GetMaxPower() or reactor.currentPower.first)
            end
        end

        scaleLevel = math.min(scaleLevel, statBoost.powerScaling:size() - 1)
        local multiplier = (scaleLevel >= 0 and statBoost.powerScaling[scaleLevel] or statBoost.powerScalingNoSys)

        return multiplier
    end

    return 1
end

local healerAppropriateForCrewMethods = {
    ["ShipSystem"] = function(system, crew)
        return system:GetEffectivePower() > 0
        and ((system.name == systemIds[5] and crew:IsCrew()) or (system.name == systemIds[4] and crew:IsDrone()))
    end,
    ["CrewMember"] = function(healer, crew) return healer ~= crew end,
    ["ActivatedPower"] = function(power, crew)
        if power.crew == crew then
            return power_net_self_health_effect(power, crew) > 0
        end

        local healSpeed = crew.extend:CalculateStat(Hyperspace.CrewStat.HEAL_SPEED_MULTIPLIER)
        local healAmount = power.def.crewHealth + (get_toggle_number(power.def.tempPower.healCrewAmount) * healSpeed)
        local relevantStatBoosts = health_affecting_stat_boosts(power.def.statBoosts, power.def.roomStatBoosts, power.def.tempPower.statBoosts)

        for _, statBoost in ipairs(relevantStatBoosts) do
            if stat_boost_affects_crew(statBoost, crew) then
                local multiplier = stat_boost_multiplier_on_ship(statBoost, Hyperspace.ships.player)
                if standardHealStats[statBoost.stat] or (statBoost.stat == Hyperspace.CrewStat.HEAL_CREW_AMOUNT and statBoost.affectsSelf) then
                    healAmount = healAmount + (statBoost.amount * healSpeed * multiplier)
                else
                    healAmount = healAmount + (statBoost.amount * multiplier)
                end
            end
        end

        return healAmount > 0
    end,
    ["AugmentDefinition"] = function(aug, crew)
        local healSpeed = crew.extend:CalculateStat(Hyperspace.CrewStat.HEAL_SPEED_MULTIPLIER)
        local healAmount = 0
        local relevantStatBoosts = health_affecting_stat_boosts(aug.statBoosts)

        for _, statBoost in ipairs(relevantStatBoosts) do
            if stat_boost_affects_crew(statBoost, crew) then
                local multiplier = stat_boost_multiplier_on_ship(statBoost, Hyperspace.ships.player)
                if standardHealStats[statBoost.stat] or (statBoost.stat == Hyperspace.CrewStat.HEAL_CREW_AMOUNT) then
                    healAmount = healAmount + (statBoost.amount * healSpeed * multiplier)
                else
                    healAmount = healAmount + (statBoost.amount * multiplier)
                end
            end
        end

        return healAmount > 0
    end
}

local function healer_appropriate_for_crew(healer, crew)
    local healerType = swig_type(healer):match("^[%a_]%w*") -- remove the thing that indicates it's a pointer
    return healerAppropriateForCrewMethods[healerType](healer, crew)
end

local function instant_heal_allowed_for_crew(crew, ship)
    if crew.extend:CalculateStat(Hyperspace.CrewStat.HEAL_SPEED_MULTIPLIER) <= 0 then return false end
    if crew_healing_status(crew) < 0 then return false end
    if crew.extend.deathTimer then return false end
    if ship:GetOxygenPercentage() < 70 and crew:CanSuffocate() and crew.extend:CalculateStat(Hyperspace.CrewStat.SUFFOCATION_MODIFIER) > 0 then return false end

    return true
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    -- Don't run if disabled or for enemy ship
    if Hyperspace.metaVariables.prof_instant_clone_heal < 1 or ship.iShipId == 1 or not Hyperspace.ships.player then
        return
    end

    local cApp = Hyperspace.App
    local gui = cApp.gui

    -- Don't run if player is in danger
    local inSafeEnviroment = gui.upgradeButton.bActive
                             and not gui.event_pause
                             and cApp.world.space.projectiles:empty()
                             and not ship.bJumping

    if not inSafeEnviroment then return end

    if ship:HasSystem(13) and is_ship_stable(ship) then -- 13 is clonebay
        ship.cloneSystem.fTimeToClone = ship.cloneSystem.fTimeGoal
    end
    if is_ship_super_stable(ship) then
        local healers = get_healers_on_ship(ship)
        for crew in vter(ship.vCrewList) do
            if crew_heals_self(crew) then
                crew:DirectModifyHealth(9999)
            elseif instant_heal_allowed_for_crew(crew, ship) then
                for _, healer in ipairs(healers) do
                    if healer_appropriate_for_crew(healer, crew) then
                        crew:DirectModifyHealth(9999)
                        break
                    end
                end
            end
        end
    end
end)
