local vter = mods.multiverse.vter
local userdata_table = mods.multiverse.userdata_table
local time_increment = mods.multiverse.time_increment

script.on_internal_event(Defines.InternalEvents.ACTIVATE_POWER, function(power, ship)
    local crew = power.crew
    if crew.type == "unique_mafan" and crew.iRoomId > -1 then
        -- Max out resist chances on power usage
        local room = ship.ship.vRoomList[crew.iRoomId]
        room.extend.hullDamageResistChance = 100
        room.extend.sysDamageResistChance = 100
        room.extend.ionDamageResistChance = 100

        -- Set timer for resist
        userdata_table(room, "mods.multiverse.mafanResist").time = 3
    end
end)
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    local roomDefs = Hyperspace.CustomShipSelect.GetInstance():GetDefinition(ship.myBlueprint.blueprintName).roomDefs
    for room in vter(ship.ship.vRoomList) do
        local resistData = userdata_table(room, "mods.multiverse.mafanResist")
        if resistData.time then
            if resistData.time > 0 then
                -- Tick timer while it exists
                resistData.time = resistData.time - time_increment()

                -- Keep resist chances maxed, needed for compatibility with other mods that alter them
                room.extend.hullDamageResistChance = 100
                room.extend.sysDamageResistChance = 100
                room.extend.ionDamageResistChance = 100
            else
                -- Delete timer when it reaches 0 and reset resist chances
                resistData.time  = nil
                if roomDefs:has_key(room.iRoomId) then
                    local roomDef = roomDefs[room.iRoomId]
                    room.extend.hullDamageResistChance = roomDef.hullDamageResistChance
                    room.extend.sysDamageResistChance = roomDef.sysDamageResistChance
                    room.extend.ionDamageResistChance = roomDef.ionDamageResistChance
                else
                    room.extend.hullDamageResistChance = 0
                    room.extend.sysDamageResistChance = 0
                    room.extend.ionDamageResistChance = 0
                end
            end
        end
    end
end, -100)
