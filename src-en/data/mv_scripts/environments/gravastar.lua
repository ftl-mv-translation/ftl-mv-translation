--[[
////////////////////
INITIALIZATION
////////////////////
]]--

local lerp = mods.multiverse.lerp
local alpha_pulse = mods.multiverse.alpha_pulse
local background_tint = mods.multiverse.background_tint
local check_paused = mods.multiverse.check_paused
local time_increment = mods.multiverse.time_increment
local vter = mods.multiverse.vter
local userdata_table = mods.multiverse.userdata_table
local sign = mods.multiverse.sign
local environmentDataStar = mods.multiverse.environmentDataStar
local register_environment_star = mods.multiverse.register_environment_star
local create_damage_message = mods.multiverse.create_damage_message
local damageMessages = mods.multiverse.damageMessages

-- Apply temporary time dilation
local function temp_dilation(room, intensity, seconds)
    if room.extend.timeDilation == 0 then
        room.extend.timeDilation = intensity
        userdata_table(room, "mods.multiverse.gravastar").dilationTimer = seconds
    end
end

-- Handle temporary time dilation
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    for room in vter(ship.ship.vRoomList) do
        local roomData = userdata_table(room, "mods.multiverse.gravastar")
        if roomData.dilationTimer then
            roomData.dilationTimer = roomData.dilationTimer - time_increment()
            if roomData.dilationTimer <= 0 then
                roomData.dilationTimer = nil
                room.extend.timeDilation = 0
            end
        end
    end
end)

-- Open breaches, deal damage and apply time dilation
local function do_gravity_impact(ship)
    if not (ship.bDestroyed or ship.bJumping) then
        -- Generate a random line using a room center and an angle
        local theta = math.random()*2*math.pi
        local linePoint1 = ship:GetRandomRoomCenter()
        local linePoint2 = Hyperspace.Pointf(linePoint1.x + math.cos(theta), linePoint1.y + math.sin(theta))
        local slope = (linePoint2.y - linePoint1.y)/(linePoint2.x - linePoint1.x)
        local intercept = linePoint2.y - slope*linePoint2.x

        -- Define the constants for the theshold line
        local lineA = -1
        local lineB = 1/slope
        local lineC = -intercept/slope

        -- Collect distances from room centers to line, and find mix/max distance
        local shipGraph = Hyperspace.ShipGraph.GetShipInfo(ship.iShipId)
        local distMin = mods.multiverse.INT_MAX
        local distMax = mods.multiverse.INT_MIN
        local distTable = {}
        for room in vter(shipGraph.rooms) do
            local roomCenter = shipGraph:GetRoomCenter(room.iRoomId)
            local dist = (lineA*roomCenter.x + lineB*roomCenter.y + lineC)/math.sqrt(lineA^2 + lineB^2)
            if dist > distMax then distMax = dist end
            if dist < distMin then distMin = dist end
            distTable[room.iRoomId] = dist
        end

        -- Apply temporal effect to rooms scaled by distance to line
        distMin = math.abs(distMin)
        distMax = (distMax > distMin) and distMax or distMin
        local randomSignFlip = math.random(0, 1)*2 - 1 -- Make sure a certain temporal type doesn't always end up on one side of the line
        for roomId, dist in pairs(distTable) do
            local temporalIntensity = randomSignFlip*sign(dist)*math.floor(4*math.abs(dist)/distMax)
            temp_dilation(shipGraph.rooms[roomId], temporalIntensity, 12)
        end

        -- Start fires, open breaches and deal damage
        for i = 1, math.random(3, 4) do
            -- Pick a random room
            local room = shipGraph.rooms[math.random(0, shipGraph.rooms:size() - 1)].iRoomId

            if math.random(2) == 1 then -- Flip coin for fire/breach
                ship:StartFire(room)
            else
                ship.ship:BreachRandomHull(room)
            end

            if math.random(2) == 1 then  -- Flip coin for damage
                ship:DamageHull(1, false)
                local sys = ship:GetSystemInRoom(room)
                if sys then sys:AddDamage(1) end
                local roomCenter = shipGraph:GetRoomCenter(room)
                create_damage_message(ship.iShipId, damageMessages.ONE, roomCenter.x, roomCenter.y)
            end
        end
    end
end

-- Register the hazard
register_environment_star("gravastar", "loc_environment_gravity", "loc_gravity_requeue", "warnings/danger_hole.png", "gravityWave", "map_gravastar_loc", "GRAVITY_SURGE", "GRAVITY_SURGE_QUEUE", 1, 1.5, do_gravity_impact)
local envData = environmentDataStar.gravastar

-- Load assets
local gravastar
local gravastarGlow
local gravastarRingTop
local gravastarRingBottom
do
    local tex = Hyperspace.Resources:GetImageId("effects/gravastar.png")
    gravastar = Graphics.CSurface.GL_CreateImagePrimitive(tex, -tex.width/2, -tex.height/2, tex.width, tex.height, 20, Graphics.GL_Color(1, 1, 1, 1))
    gravastar.textureAntialias = true
    tex = Hyperspace.Resources:GetImageId("effects/gravastar_glow.png")
    gravastarGlow = Graphics.CSurface.GL_CreateImagePrimitive(tex, -tex.width/2, -tex.height/2, tex.width, tex.height, 20, Graphics.GL_Color(1, 1, 1, 1))
    gravastarGlow.textureAntialias = true
    tex = Hyperspace.Resources:GetImageId("effects/pulsar_frontL.png")
    gravastarRingTop = Graphics.CSurface.GL_CreateImagePrimitive(tex, -tex.width/2, -tex.height/2 + 20, tex.width, tex.height, 20, Graphics.GL_Color(1, 1, 1, 1))
    gravastarRingTop.textureAntialias = true
    tex = Hyperspace.Resources:GetImageId("effects/pulsar_backL.png")
    gravastarRingBottom = Graphics.CSurface.GL_CreateImagePrimitive(tex, -tex.width/2, -tex.height/2 + 20, tex.width, tex.height, 20, Graphics.GL_Color(1, 1, 1, 1))
    gravastarRingBottom.textureAntialias = true
end

-- Delay before rendering ring
local flashRingDelay = 0.8

-- Pulse timer
local pulseTime = 3
local pulseTimeCurrent = 0

--[[
////////////////////
VISUALS
////////////////////
]]--

-- Progress pulse timer for gravastar
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if Hyperspace.playerVariables.loc_environment_gravity > 0 then
        if not (check_paused() or Hyperspace.Settings.lowend) then
            pulseTimeCurrent = pulseTimeCurrent + time_increment()
            if pulseTimeCurrent > pulseTime then
                pulseTimeCurrent = pulseTimeCurrent - pulseTime
            end
        end
    end
end)

-- Render gravastar
script.on_render_event(Defines.RenderEvents.LAYER_FOREGROUND, function()
    if Hyperspace.playerVariables.loc_environment_gravity > 0 and not Hyperspace.App.world.space.bNebula then
        Graphics.CSurface.GL_PushMatrix()
        Graphics.CSurface.GL_Translate(766, 235)

        local tint = background_tint()
        local ringTime = envData.flashTime + envData.flashDelay - flashRingDelay
        if not Hyperspace.Settings.lowend and envData.flashTimeCurrent > 0 and envData.flashTimeCurrent <= ringTime then
            local progress = 1 - envData.flashTimeCurrent/(ringTime)
            local scale = lerp(0.4, 6, progress)
            local ringColor = Graphics.GL_Color(math.min(1.0, lerp(1.2, 0.7, progress)), math.min(1.0, lerp(1.5, 0.2, progress)), 1.0, alpha_pulse(ringTime, envData.flashTimeCurrent))

            Graphics.CSurface.GL_PushMatrix()
            Graphics.CSurface.GL_Scale(scale, scale, 0)
            Graphics.CSurface.GL_RenderPrimitiveWithColor(gravastarRingBottom, ringColor)
            Graphics.CSurface.GL_PopMatrix()

            Graphics.CSurface.GL_RenderPrimitiveWithColor(gravastar, tint)
            tint.a = alpha_pulse(pulseTime, pulseTimeCurrent)
            Graphics.CSurface.GL_RenderPrimitiveWithColor(gravastarGlow, tint)

            Graphics.CSurface.GL_PushMatrix()
            Graphics.CSurface.GL_Scale(scale, scale, 0)
            Graphics.CSurface.GL_RenderPrimitiveWithColor(gravastarRingTop, ringColor)
            Graphics.CSurface.GL_PopMatrix()
        else
            Graphics.CSurface.GL_RenderPrimitiveWithColor(gravastar, tint)
            if not Hyperspace.Settings.lowend then
                tint.a = alpha_pulse(pulseTime, pulseTimeCurrent)
                Graphics.CSurface.GL_RenderPrimitiveWithColor(gravastarGlow, tint)
            end
        end

        Graphics.CSurface.GL_PopMatrix()
    end
end, function() end)

-- Show flash for gravity wave
script.on_internal_event(Defines.InternalEvents.GET_HAZARD_FLASH, function()
    if Hyperspace.playerVariables.loc_environment_gravity > 0 and envData.flashTimeCurrent > 0 and envData.flashTimeCurrent <= envData.flashTime then
        local alpha = alpha_pulse(envData.flashTime, envData.flashTimeCurrent)
        return lerp(0.6, 1.0, alpha), alpha, 1.0, alpha
    end
end)
