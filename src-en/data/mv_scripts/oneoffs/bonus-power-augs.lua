-- List of augments which provide bonus power
-- Index is the augment, value is the ID of the system it powers
local bonusPowerAugs = {
    UPG_TELEPORTER_POWER = 9
}

-- Make augments provide bonus power to their specified systems
script.on_internal_event(Defines.InternalEvents.SET_BONUS_POWER, function(system, amount)
    local ship = Hyperspace.ships(system._shipObj.iShipId)
    if ship then
        for augName, sysId in pairs(bonusPowerAugs) do
            if system:GetId() == sysId then
                amount = amount + ship:GetAugmentationValue(augName)
            end
        end
    end
    return Defines.Chain.CONTINUE, amount
end)
