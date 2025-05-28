--[[
////////////////////
INITIALIZATION
////////////////////
]]--

local string_starts = mods.multiverse.string_starts
local time_increment = mods.multiverse.time_increment
local background_tint = mods.multiverse.background_tint
local register_environment = mods.multiverse.register_environment

local nebulaClouds = {}
local hubClouds = {}

local rows = 6
local columns = 9

local hubNumber = 5
local hubGenTime = 3
local hubScaleMin = 1
local hubScaleMax = 1.25

local xJump = 160
local yJump = 144

local minScale = 0.5
local maxScaleRandom = 0.65
local scaleIncrease = 0.15

local lifeTime = 12
local fadeInTime = 3
local fadeOutTime = 3

local minOpacity = 0.7
local maxOpacity = 0.8

local imageString = "stars/nebula_large_c.png"
local eventString = "NEBULA_LIGHT_"
local playerVar = "loc_environment_lightnebula"

local warningString = "warnings/danger_nebula.png"

local initialPosX = (math.random()*131072) % 131 - 65

-- Register the hazard
register_environment("light_nebula", playerVar, warningString)

--[[
////////////////////
LOGIC
////////////////////
]]--

-- Generate positions for base static clouds
local function gen_hub_clouds()
    for k = 1, hubNumber, 1  do
        local x = math.random(0, columns)
        local y = math.random(0, rows)
        hubClouds[k] = {x = x, y = y, scale = 1, genTimer = 0}
        local hubCloud = hubClouds[k]
        hubCloud.scale = (math.random()*(hubScaleMax - hubScaleMin)) + hubScaleMin
        hubCloud.genTimer = math.random()*hubGenTime
    end
end
gen_hub_clouds()

-- Track whether we've entered a location that is or isn't a light nebula
script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
    local isLightNebula = string_starts(event.eventName, eventString)
    local newLocation = Hyperspace.App.world.starMap.currentLoc.event.eventName == event.eventName
    if isLightNebula and not Hyperspace.App.world.space.bNebula and (newLocation or Hyperspace.playerVariables[playerVar] == 0) then
        Hyperspace.playerVariables[playerVar] = 1
        gen_hub_clouds()
        initialPosX = (math.random()*131072) % 131 - 65
    elseif not isLightNebula and newLocation then
        Hyperspace.playerVariables[playerVar] = 0
    end
end)

-- Create a table to track a cloud
local function create_cloud(x, y)
    local cloudTemp = {x = 0, y = 0, scale = 1.5, timerScale = 0, opacity = 1, revOp = 0, fade = 0}
    cloudTemp.x = x
    cloudTemp.y = y

    cloudTemp.scale = (math.random()*(maxScaleRandom - minScale)) + minScale
    cloudTemp.timerScale = 0

    cloudTemp.opacity = 0.05
    cloudTemp.revOp = math.random(0, 1)
    return cloudTemp
end

-- Cloud Logic
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if ship ~= Hyperspace.ships.player then return end
    -- Base static clouds
    if not Hyperspace.App.world.bStartedGame or (Hyperspace.App.world.bStartedGame and Hyperspace.playerVariables[playerVar] == 1) then
        for _, hubTable in ipairs(hubClouds) do
            -- Periodically spawn dynamic clouds on top of hub clouds
            if not Hyperspace.App.world.bStartedGame or Hyperspace.App.world.bStartedGame then
                hubTable.genTimer = hubTable.genTimer - time_increment()
                if hubTable.genTimer <= 0 then
                    hubTable.genTimer = hubGenTime
                    local newx = hubTable.x + math.random(-1, 1)
                    local newy = hubTable.y + math.random(-1, 1)
                    if newx <= 0 then newx = 0 end
                    if newx >= columns then newx = columns end
                    if newy <= 0 then newy = 0 end
                    if newy >= rows then newy = rows end
                    table.insert(nebulaClouds, create_cloud(newx, newy))
                end
            end
        end
    end

    -- Top dynamic clouds
    if not Hyperspace.App.world.bStartedGame or (Hyperspace.App.world.bStartedGame and Hyperspace.playerVariables[playerVar] == 1) then
        local cloudCount = #nebulaClouds
        local cloudIndex = 1
        while cloudIndex <= cloudCount do
            local indexIncrement = 1
            local cloud = nebulaClouds[cloudIndex]

            -- Increase scale over time
            cloud.timerScale = cloud.timerScale + time_increment()
            cloud.scale = cloud.scale + ((scaleIncrease/lifeTime)*time_increment())

            -- Remove cloud when life has expired,
            -- adjust counters to account for missing table elements
            if cloud.timerScale >= lifeTime then
                table.remove(nebulaClouds, cloudIndex)
                cloudCount = cloudCount - 1
                indexIncrement = 0
            end

            -- Fade in, blink and fade out
            if cloud.timerScale >= (lifeTime - fadeOutTime) then
                cloud.opacity = math.max(cloud.opacity - time_increment()/fadeOutTime, 0.025)
                if cloud.fade == 0 then
                    cloud.fade = 1
                end
            elseif cloud.timerScale < fadeInTime then
                cloud.opacity = math.min(cloud.opacity + time_increment()/fadeOutTime, maxOpacity)
            elseif cloud.revOp == 0 then
                cloud.opacity = math.min(cloud.opacity + 0.1*time_increment(), maxOpacity)
                if cloud.opacity >= maxOpacity then
                    cloud.revOp = 1
                end
            else
                cloud.opacity = cloud.opacity - 0.1*time_increment()
                if cloud.opacity <= minOpacity then
                    cloud.revOp = 0
                end
            end

            cloudIndex = cloudIndex + indexIncrement
        end
    end
end)

-- Cloud Rendering
script.on_render_event(Defines.RenderEvents.LAYER_FOREGROUND, function() end, function() 
    -- Base static clouds
    if not Hyperspace.App.world.bStartedGame or (Hyperspace.App.world.bStartedGame and Hyperspace.playerVariables[playerVar] == 1) then
        local tint = background_tint()
        for _, hubTable in ipairs(hubClouds) do
            -- Render the cloud
            if Hyperspace.App.world.bStartedGame then
                local cloudImageTemp = Hyperspace.Resources:CreateImagePrimitiveString(imageString, -256, -200, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)

                Graphics.CSurface.GL_PushMatrix()
                Graphics.CSurface.GL_Translate((hubTable.x*xJump + initialPosX) - 20, (hubTable.y*yJump + initialPosX) - 16, 0)
                Graphics.CSurface.GL_Scale(hubTable.scale,hubTable.scale,0)
                Graphics.CSurface.GL_RenderPrimitiveWithColor(cloudImageTemp, tint)
                Graphics.CSurface.GL_PopMatrix()
                Graphics.CSurface.GL_DestroyPrimitive(cloudImageTemp)
            end
        end
    end

    -- Top dynamic clouds
    if not Hyperspace.App.world.bStartedGame or (Hyperspace.App.world.bStartedGame and Hyperspace.playerVariables[playerVar] == 1 and not Hyperspace.Settings.lowend) then
        local tint = background_tint()
        for _, cloud in ipairs(nebulaClouds) do

            -- Render the cloud
            if Hyperspace.App.world.bStartedGame then
                local cloudImageTemp = Hyperspace.Resources:CreateImagePrimitiveString(imageString, -256, -200, 0, Graphics.GL_Color(1, 1, 1, 1), cloud.opacity, false)

                Graphics.CSurface.GL_PushMatrix()
                Graphics.CSurface.GL_Translate((cloud.x*xJump + initialPosX) - 20, (cloud.y*yJump + initialPosX) - 16, 0)
                Graphics.CSurface.GL_Scale(cloud.scale, cloud.scale, 0)
                Graphics.CSurface.GL_RenderPrimitiveWithColor(cloudImageTemp, tint)
                Graphics.CSurface.GL_PopMatrix()
                Graphics.CSurface.GL_DestroyPrimitive(cloudImageTemp)
            end
        end
    end
end)
