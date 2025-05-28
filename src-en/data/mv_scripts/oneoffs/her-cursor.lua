--[[
////////////////////
INITIALIZATION
////////////////////
]]--

local time_increment = mods.multiverse.time_increment
local offset_point_direction = mods.multiverse.offset_point_direction
local get_distance = mods.multiverse.get_distance

-- Player cursor variables
local playerCursorState = 1
local playerCursorDelay = 0.1
local playerCursorRestore = nil
local playerCursorRestoreInvalid = nil
local playerReady = false

-- Her cursor variables
local cursors = {}
local startingArea = {x = 759, y = 34, w = 510, h = 564 - 200}
local targetPoints = {}
local speedModifier = 35
local cooldownConstant = {20, 10}
local spawnCooldown = 0

-- How close the player cursor needs to be to click on Her cursors
local clickDistance = 30

-- Timer to track how long the player can't pause for
local unpausedTimerConstant = 5
local unpausedTimer = 0

-- Sounds
local herCursorSpawnPath = "hc_spawn_"
local herCursorSpawnNumber = 7

-- Textures
local cursorHerTex
local cursorHerPrim
local unpausedPrim
do
    cursorHerTex = {
        Hyperspace.Resources:GetImageId("mouse/pointer_her_1.png"),
        Hyperspace.Resources:GetImageId("mouse/pointer_her_2.png"),
        Hyperspace.Resources:GetImageId("mouse/pointer_her_3.png"),
        Hyperspace.Resources:GetImageId("mouse/pointer_her_4.png"),
        Hyperspace.Resources:GetImageId("mouse/pointer_her_5.png")
    }
    cursorHerPrim = {
        Hyperspace.Resources:CreateImagePrimitive(cursorHerTex[1], -6, -6, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
        Hyperspace.Resources:CreateImagePrimitive(cursorHerTex[2], -6, -6, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
        Hyperspace.Resources:CreateImagePrimitive(cursorHerTex[3], -6, -6, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
        Hyperspace.Resources:CreateImagePrimitive(cursorHerTex[4], -6, -6, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
        Hyperspace.Resources:CreateImagePrimitive(cursorHerTex[5], -6, -6, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
    }

    unpausedPrim = Hyperspace.Resources:CreateImagePrimitiveString("mouse/paused_her.png", 512 - 11, 526, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
end

--[[
////////////////////
LOGIC
////////////////////
]]--

local function her_cursor_logic()
    local commandGui = Hyperspace.App.gui
    if Hyperspace.playerVariables.her_cursor_enabled == 1 then

        -- Run the logic after the first unpause
        if not playerReady and commandGui.bPaused then return end
        playerReady = true

        -- Cooldown timer
        if spawnCooldown > 0 and not commandGui.event_pause then spawnCooldown = spawnCooldown - time_increment(false) end

        -- Spawn cursors
        if #cursors <= 0 and #targetPoints >= 1 and spawnCooldown <= 0 then
            for i = 1, Hyperspace.playerVariables.her_cursor_level do
                local randomX = math.random(startingArea.x, startingArea.x + startingArea.w)
                local randomY = math.random(startingArea.y, startingArea.y + startingArea.h)
                local target = math.random(1, #targetPoints)
                table.insert(cursors, {
                    x = randomX, y = randomY,
                    state = i%5 + 1,
                    target = target,
                    currentHeading = 0,
                    progress = 100,
                    speed = 1,
                    alpha = 0,
                    spawning = true,
                    dying = false,
                    spawnTime = 1
                })
            end

            -- Play spawn sound
            Hyperspace.Sounds:PlaySoundMix(herCursorSpawnPath..tostring(math.random(1, herCursorSpawnNumber)), -1, false)
        end

        -- No need to bother if there are no cursors
        if #cursors <= 0 then return end

        -- Handle logic for each cursor
        local cursorsRemove = {}
        for n, cursorTable in ipairs(cursors) do

            -- Spawning animation
            if cursorTable.spawning then
                cursorTable.spawnTime = cursorTable.spawnTime - time_increment(false)
                if cursorTable.spawnTime <= 0 then
                    cursorTable.spawning = false
                    cursorTable.alpha = 1
                else
                    cursorTable.x = cursorTable.x + math.random(-5, 5)
                    cursorTable.y = cursorTable.y + math.random(-5, 5)
                    cursorTable.alpha = 1 - cursorTable.spawnTime
                end
            end

            -- Dying animation
            if cursorTable.dying then
                cursorTable.alpha = cursorTable.alpha - time_increment(false)
                cursorTable.x = cursorTable.x + math.random(-10, 10)
                cursorTable.y = cursorTable.y + math.random(-10, 10)
                if cursorTable.alpha <= 0 then
                    table.insert(cursorsRemove, n)
                end
            end

            -- Switching cursor sprites
            cursorTable.state = (cursorTable.state + (Hyperspace.FPS.SpeedFactor/8))
            if cursorTable.state >= 5 then cursorTable.state = cursorTable.state - 5 end

            -- Cursor targetting ship systems
            if #targetPoints >= cursorTable.target and not (commandGui.bPaused or commandGui.event_pause or commandGui.menu_pause) then

                -- Change direction
                if cursorTable.progress > 100 then
                    cursorTable.progress = 0
                    local targetPointX = targetPoints[cursorTable.target].x
                    local targetPointY = targetPoints[cursorTable.target].y

                    cursorTable.speed = (math.random() - 0.5) + (2 ^ math.max(Hyperspace.metaVariables.challenge_level,2))
                    local targetAngle = math.deg(math.atan((targetPointY - cursorTable.y), (targetPointX - cursorTable.x)))
                    -- If close to target fly straight, otherwise fly in a random angle towards it
                    if get_distance(cursorTable, targetPoints[cursorTable.target]) <= 250 then
                        cursorTable.currentHeading = targetAngle
                        cursorTable.speed = cursorTable.speed * 0.75
                    else
                        local randomAngle = targetAngle + math.random(-5, 5) * 7
                        cursorTable.currentHeading = randomAngle
                    end
                end
                -- Move in the right direction
                local distance = (time_increment(false)) * speedModifier * cursorTable.speed
                local newPoint = offset_point_direction(cursorTable.x, cursorTable.y, cursorTable.currentHeading, distance)
                cursorTable.x = newPoint.x
                cursorTable.y = newPoint.y
                cursorTable.progress = cursorTable.progress + distance

                -- If close to system box ion damage the linked system
                if get_distance(cursorTable, targetPoints[cursorTable.target]) <= 5 then
                    table.insert(cursorsRemove, n)
                    local sys = Hyperspace.ships.player:GetSystem(targetPoints[cursorTable.target].id)
                    sys:IonDamage(1)
                    Hyperspace.Sounds:PlaySoundMix("ionHit1", -1, false)
                end

            -- Cursor targetting player cursor
            elseif (commandGui.bPaused and not (commandGui.event_pause or commandGui.menu_pause)) then

                -- Chase the player cursor 
                if cursorTable.progress > 100 then
                    cursorTable.progress = 0
                    local targetPointX = Hyperspace.Mouse.position.x
                    local targetPointY = Hyperspace.Mouse.position.y

                    cursorTable.speed = (math.random() - 0.5) + (2 ^ Hyperspace.metaVariables.challenge_level)
                    local targetAngle = math.deg(math.atan((targetPointY - cursorTable.y), (targetPointX - cursorTable.x)))
                    if get_distance(cursorTable, Hyperspace.Mouse.position) <= 250 then
                        cursorTable.currentHeading = targetAngle
                        cursorTable.speed = cursorTable.speed * 0.75
                    else
                        local randomAngle = targetAngle + math.random(-5, 5) * 7
                        cursorTable.currentHeading = randomAngle
                    end
                end

                local distance = (time_increment(false)) * speedModifier * cursorTable.speed * 2
                local newPoint = offset_point_direction(cursorTable.x, cursorTable.y, cursorTable.currentHeading, distance)
                cursorTable.x = newPoint.x
                cursorTable.y = newPoint.y
                cursorTable.progress = cursorTable.progress + distance

                -- Give the unpaused state when reaching the player cursor
                if get_distance(cursorTable, Hyperspace.Mouse.position) <= 5 then
                    Hyperspace.playerVariables.unpaused = 1
                    commandGui.bPaused = false
                    unpausedTimer = unpausedTimerConstant
                    cursorTable.x = math.random(startingArea.x, startingArea.x + startingArea.w)
                    cursorTable.y = math.random(startingArea.y, startingArea.y + startingArea.h)
                    Hyperspace.Sounds:PlaySoundMix("ionHit1", -1, false)
                end
            end

            -- Remove cursors
            for _, n2 in ipairs(cursorsRemove) do
                table.remove(cursors, n2)
            end
            if #cursors <= 0 then
                spawnCooldown = cooldownConstant[Hyperspace.playerVariables.her_cursor_serious + 1]
            end
        end

        -- Punishing menu pause abuser
        -- Will basically always catch the player cursor when unpausing from menu pause
        if commandGui.menu_pause and not commandGui.event_pause then
            commandGui.bPaused = true
            for _, cursorTable in ipairs(cursors) do
                cursorTable.x = Hyperspace.Mouse.position.x
                cursorTable.y = Hyperspace.Mouse.position.y
            end
        end

        -- Clear variables if you go back to the hangar or menu
        if Hyperspace.App.menu.shipBuilder.bOpen or not Hyperspace.App.world.bStartedGame then
            Hyperspace.playerVariables.unpaused = 0
            Hyperspace.playerVariables.her_cursor_enabled = 0
        end
    end
end

script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_MOVE, function(systemBox)
    if Hyperspace.playerVariables.her_cursor_enabled == 1 and systemBox.bPlayerUI then
        local sysId = systemBox.pSystem.iSystemType
        for _, targetPointTable in ipairs(targetPoints) do
            if targetPointTable.id == sysId then return    end
        end
        table.insert(targetPoints, {id = sysId, x = systemBox.location.x + 30, y = systemBox.location.y + 409})
    end
end)


-- Main Render Loop
script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function()
    local commandGui = Hyperspace.App.gui
    if Hyperspace.playerVariables.unpaused == 1 and not (commandGui.event_pause or commandGui.menu_pause) then
        Graphics.CSurface.GL_RenderPrimitive(unpausedPrim)
    end
    if Hyperspace.playerVariables.her_cursor_enabled == 1 then
        for _, cursorTable in ipairs(cursors) do
            --Render Cursor
            Graphics.CSurface.GL_PushMatrix()
            Graphics.CSurface.GL_Translate(cursorTable.x, cursorTable.y, 0)
            Graphics.CSurface.GL_RenderPrimitiveWithAlpha(cursorHerPrim[math.ceil(cursorTable.state)], cursorTable.alpha)
            Graphics.CSurface.GL_PopMatrix()
        end
    end
end, function() end)

-- Main Logic Loop
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local commandGui = Hyperspace.App.gui

    -- Her cursor logic
    her_cursor_logic()

    -- Player cursor animation during unpause
    if Hyperspace.playerVariables.unpaused == 1 then
        if not playerCursorRestore then
            playerCursorRestore = Hyperspace.Mouse.validPointer
            playerCursorRestoreInvalid = Hyperspace.Mouse.invalidPointer
        end
        playerCursorDelay = playerCursorDelay - time_increment(false)
        if playerCursorDelay <= 0 then
            playerCursorDelay = 0.1
            playerCursorState = playerCursorState + 1
            if playerCursorState > #cursorHerTex then
                playerCursorState = 1
            end
            Hyperspace.Mouse.validPointer = cursorHerTex[playerCursorState]
            Hyperspace.Mouse.invalidPointer = cursorHerTex[playerCursorState]
            Hyperspace.Mouse.animateDoor = 0
        end
    elseif playerCursorRestore then
        Hyperspace.Mouse.validPointer = playerCursorRestore
        Hyperspace.Mouse.invalidPointer = playerCursorRestoreInvalid
        playerCursorRestore = nil
        playerCursorRestoreInvalid = nil
    end

    -- Unpause player cursor logic
    if Hyperspace.playerVariables.unpaused == 1 and not (commandGui.event_pause or commandGui.menu_pause) then
        -- Unpause timer
        unpausedTimer = unpausedTimer - time_increment(false)
        if unpausedTimer <= 0 then
            Hyperspace.playerVariables.unpaused = 0
        end

        -- Remove the ability to select crew
        local crewControl = Hyperspace.App.gui.crewControl
        crewControl.potentialSelectedCrew:clear()
        crewControl.selectedCrew:clear()

        -- Remove the ability to pause
        if commandGui.bPaused then
            commandGui.bPaused = false
        end
    end
end)

-- Banish her cursor on click logic
script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x, y)
    local commandGui = Hyperspace.App.gui
    if #cursors > 0 and not (commandGui.bPaused or commandGui.event_pause or commandGui.menu_pause) then
        local cursorsRemove = {}
        for _, cursorTable in ipairs(cursors) do
            if not cursorTable.spawning and not cursorTable.dying and get_distance(cursorTable, Hyperspace.Mouse.position) <= clickDistance then
                cursorTable.dying = true
                Hyperspace.Sounds:PlaySoundMix(herCursorSpawnPath .. tostring(math.random(1, herCursorSpawnNumber)), -1, false)
            end
        end
        for _, n in ipairs(cursorsRemove) do
            table.remove(cursors, n)
        end
        if #cursors <= 0 then
            spawnCooldown = cooldownConstant[Hyperspace.playerVariables.her_cursor_serious + 1]
        end
    end
    return Defines.Chain.CONTINUE
end)

-- Invoke the cursor logic
script.on_game_event("HER_FIGHT", false, function()
    cursors = {}
    targetPoints = {}
    Hyperspace.playerVariables.her_cursor_enabled = 1
    Hyperspace.playerVariables.her_cursor_level = Hyperspace.metaVariables.challenge_level == 3 and 2 or 1
    Hyperspace.playerVariables.her_cursor_serious = 0
    spawnCooldown = cooldownConstant[1]
    playerReady = false
end)

-- Reduce cooldown when the CEL is here
script.on_game_event("HER_SUPPORT", false, function()
    Hyperspace.playerVariables.her_cursor_serious = 1
end)

-- Disable everything when the fight is over
script.on_game_event("HER_FINALE", false, function()
    spawnCooldown = mods.multiverse.INT_MAX
    for _, cursorTable in ipairs(cursors) do cursorTable.dying = true end
    Hyperspace.playerVariables.unpaused = 0
end)
script.on_game_event("HER_FINALE_REAL", false, function()
    Hyperspace.playerVariables.her_cursor_enabled = 0
    Hyperspace.playerVariables.unpaused = 0
end)
